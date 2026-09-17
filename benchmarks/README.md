# Gas benchmark harnesses

Foundry tests behind the numbers on the [Gas efficiency](/concepts/gas-efficiency/) page.
Each protocol compiles under its own production toolchain settings, so the comparison
measures code and architecture rather than compiler tuning.

## Layout

- `lab/ekubo/` — Ekubo EVM swaps, mints and pool initialization (`EkuboGas.t.sol`, plus
  `Flame.t.sol` for the single-call flamegraph capture)
- `lab/v4/` — Uniswap v4 (`V4Gas.t.sol`, `Flame.t.sol`)
- `lab/v3/` — Uniswap v3 (`V3Gas.t.sol`, `Flame.t.sol`)
- `lab/MockERC20.json` — the single shared token artifact deployed via `deployCode`
  in all three lab harnesses, so ERC20 transfer costs cannot skew the comparison
- `pools-per-swap/` — the pools-touched-per-swap-transaction measurement behind the
  chain-wide section (`measure.mjs`, `results.json`); see below
- `fork/` — mainnet-fork validation at pinned block `25991868`
  (`ForkEkuboReal.t.sol`, `ForkV3.t.sol`, `ForkV4.t.sol` for swaps;
  `ForkMintEkubo.t.sol`, `ForkMintV3.t.sol`, `ForkMintV4.t.sol` for mints through the
  production position managers; `ForkProbe.t.sol` for the pool identifiers;
  `calldata-*.hex` reference calldata, `encode-yul-route.mjs`)

`*.json` files next to each harness are the raw `snapshots/` output of a full run of
that test contract. `remappings.txt` files contain the original absolute paths and will
need adjusting; the dependency pins below are what matter for reproduction.

## What a snapshot number is

Every measured call runs under `forge-config: default.isolate = true`. Isolation gives
each top-level call from the test its own EVM context, so end-of-call refunds are
applied, and `vm.snapshotGasLastCall` reports **the execution gas of that call, net of
refunds**. It does not include the 21,000 transaction base cost or calldata: the
`Flame.t.sol` captures are not isolated, and the flamegraph frame for the same router
call (for example `Router.swapAllowPartialFill` at 87,416) equals the isolated snapshot
(`ekubo single erc20 steady-state`, 87,416) to the gas unit. Transaction totals on the
docs page are computed as snapshot + 21,000 + the calldata gas of a reference file.

Refunds matter for one series. Isolated snapshots are post-refund, capped at 1/5 of gas
used (EIP-3529). The v3 harness records `gross before refund` and `refund granted` next to
every snapshot via `vm.lastCallGas`; every Ekubo and v4 measurement has zero refund, so
their snapshot, `lastCallGas().gasTotalUsed`, and a `gasleft()` delta around the call
agree to within the caller's own overhead (roughly 1–5k, the CALL and argument copying).

## Lab methodology (all three harnesses)

Each test runs on a fresh chain. Pools are capitalized in setup, and every measured call
is preceded by one identical unmeasured warm-up call, so the number is the steady state
of an established pool. A separate `first swap in fresh pool` measurement has no warm-up:
on v3 and v4 it costs exactly 17,100 more (one zero-to-nonzero SSTORE of the fee-growth
accumulator, 20,000 instead of 2,900; confirmed with `vm.startStateDiffRecording`, which
shows one fresh slot for v3 and v4 and none for Ekubo). Ekubo's `initializePool` writes
both fee-per-liquidity slots up front, so its first swap costs the same as any other
(87,384 against 87,416 in steady state).

- Concentrated pools, 0.3% fee, one position covering the whole tick space, so no swap
  crosses an initialized tick.
- Pools initialized strictly inside a tick (Ekubo tick 3050, Uniswap tick 30), never on a
  tick-spacing multiple.
- Economically matched liquidity: 1M tokens a side on Ekubo and v4; v3 mints the
  equivalent liquidity (998501199320305883812938) computed for the same amounts.
- 1-token exact-input swaps, both directions. Every recipient already holds the output
  token, and every router delivers output to the calling user, so no measured call pays
  a zero-to-nonzero balance write the others avoid.
- Each protocol's cheapest path an externally owned account can actually send:
  - Ekubo: the production Solidity `Router`. Its single-swap entry
    (`swapAllowPartialFill`, tests `test_gas_single_*`) and its multihop entry
    (`multihopSwap`, tests `test_gas_route_*`; the 1-pool route is the same swap
    through the multihop path). A true-minimal locker (`MinimalEkuboLocker`: lock,
    swap, pay, withdraw; tests `test_gas_single_*_minimalLocker`) is recorded for a
    like-for-like comparison with the v4 minimal locker.
  - v4: a true-minimal locker (`MinimalSwapRouter`: unlock, swap, settle, take; tests
    `test_gas_single_*`) and a single-lock multihop router (`MultiHopRouter`, tests
    `test_gas_route_*`). v4-core's own `PoolSwapTest` helper is recorded for context
    only.
  - v3: a minimal router with the production SwapRouter's token flow (`V3MultiHopRouter`:
    first hop paid straight from the user, intermediate outputs held by the router,
    last hop delivered to the user; tests `test_gas_route_*`). A direct `pool.swap`
    with the test contract as callback payer (tests `test_gas_single_*`) is recorded
    as a lower bound; an EOA cannot be a v3 callback payer, so that path is not
    sendable, and its figure moves by a few gas whenever the test contract's function
    set changes (the callback runs in the test contract).
- v3 oracle: the observation is written only by a swap that changes the tick, at most
  once per block. Two tests isolate it (`test_gas_single_tickChange_sameBlock`, 89,836,
  write skipped; `test_gas_single_tickChange_nextBlock`, 93,712, observation written):
  3,876 gas for the write.
- Mints are new positions with both boundary ticks already initialized (different salt
  on Ekubo and v4, different owner on v3); v3 also records adding to an existing position
  (`test_gas_mint_samePosition`, 121,496 net). Every v3 mint earns a 2,800 refund.
- Pool initialization (`test_gas_initializePool`) is recorded in each harness's snapshot
  file but is a one-time cost and is excluded from the docs page by design, as is every
  cold-tick mint variant; the page's mint rows are subsequent mints into initialized
  ticks only. Ekubo's `initializePool` pre-writes the two fee-accumulator slots (value 1),
  which is why its first swap and its position snapshots cost the same in every pool.
- Mint attribution for the docs page's component table comes from `-vvvv` traces of the
  measured mint call: Ekubo `Core.updatePosition` 106,407, settlement 2 × (5,914 +
  12,602 + 2,054) = 41,140, plumbing 31,473; v4 `PoolManager.modifyLiquidity` 63,358,
  settlement 2 × (1,898 + 10,602 + 2,499) = 29,998, plumbing 68,832 (v4-core's
  `PoolModifyLiquidityTest`, which also reads pool state, balances and deltas); v3 `mint`
  frame 141,180 gross minus the callback (24,095) and four balance checks (6,100) =
  110,985 gross pool internals, 108,185 net of the 2,800 refund. A one-off probe (not in
  the committed snapshots) that swaps once in each direction before the warm-up mint
  measures Ekubo 179,020 (unchanged), v4 201,988 (`modifyLiquidity` 103,158), v3 178,224
  net / 181,024 gross: the Uniswap position fee-growth snapshots go zero-to-nonzero in a
  traded pool, +39,800 each.
- `Flame.t.sol` files capture one steady-state call for the flamegraphs; their router
  call frames equal the corresponding snapshots (Ekubo Router single 87,416, v4 minimal
  locker single 103,533, v3 1-pool route 94,078). The root frame of each SVG also
  includes the test's own call into the router.
- Native input: the Ekubo and v4 paths each make exactly two value-bearing calls (the
  user's call into the router, then one internal call into Core or PoolManager).

`vm.cool` was tried while building the harnesses and changed no figure; no committed
test uses it. Switching the v3 and v4 harnesses from `cancun` to `osaka` was checked and
changes none of their swap figures.

## Fork methodology

Same pair (USDT to USDC), two sizes (1000 and 100 USDT), warmed with one identical
unmeasured swap, negligible tick movement (0–1 ticks), pinned block `25991868`
(timestamp 1789583783, gas limit 59,999,943), every call isolated as above. The
recipient (the test contract) holds USDT via `deal`, holds USDC after the warm-up
(asserted), and has granted a max approval to the router under test (asserted). Output
amounts are recorded as snapshot values (USDC, 6 decimals): Ekubo 999176773 / 99920076,
v4 999169404 / 99917651, v3 999209400 / 99920949.

| Leg   | Pool                                                                                                                        | Fee     | Spacing | Liquidity at block     | Tick |
| ----- | --------------------------------------------------------------------------------------------------------------------------- | ------- | ------- | ---------------------- | ---- |
| Ekubo | USDC/USDT concentrated, no extension, id `0x6fde3244f6fa747ae318aba6e982a4281febad4d22e3b134aa299a83a951895d`               | 0.0005% | 50      | 112,376,153,849,596    | 791  |
| v3    | `0x3416cF6C708Da44DB2624D63ea0AAef7113527C6` (deepest of fee 100/500/3000; cardinality 180)                                 | 0.01%   | 1       | 28,940,573,461,011,247 | 6    |
| v4    | id `0xe018f09af38956affdfeab72c2cefbcd4e6fee44d09df7525ec9dba3e51356a5`, hooks = `address(0)` (deepest of fee 100/500/3000) | 0.01%   | 1       | 380,576,221,280,057    | 6    |

Ekubo's config word `0x…53e2d6238da480000032` decodes as fee `0x53e2d6238da4` / 2^64
(0.0005%), concentrated flag set, tick spacing 50 (Ekubo ticks are 100x finer than
Uniswap's). The v4 key with `hooks = address(0)` is confirmed initialized (nonzero
`sqrtPriceX96`), so the pool has no hook.

- Ekubo: the live pool through the deployed production Yul router, with SDK-generated
  calldata (`encode-yul-route.mjs`; `calldata-yul-route.hex` for 1000 USDT,
  `calldata-yul-route-100.hex` for 100 USDT). Regenerating the 1000 USDT route from the
  SDK reproduces the committed bytes exactly. Output matched the production quoter within
  0.02%.
- v3: the deployed SwapRouter `exactInputSingle` (128,611 at both sizes).
- v4: the deployed PoolManager with a minimal locker (the Universal Router would cost
  more). USDT returns no returndata, so approvals and v4 settlement use low-level calls,
  mirroring production routers.
- WETH: one `deposit` in steady state (the account already holds WETH), 27,938: what a
  v3 user pays to wrap ETH before a native-input swap (`test_fork_weth_deposit`).

### Fork mints through the production position managers

`ForkMintEkubo.t.sol`, `ForkMintV4.t.sol` and `ForkMintV3.t.sol` mint a new full-range
position on the same three pools through each protocol's deployed position manager, the
path a liquidity provider actually sends. Same block, same `isolate` discipline; the
snapshot is the execution gas of the measured call.

- Position: each pool's widest range aligned to its tick spacing (Uniswap spacing 1:
  `-887272..887272`, the full tick range; Ekubo spacing 50: `-88722800..88722800`, the
  widest multiples of 50 inside `MIN_TICK/MAX_TICK = ±88722835`). Max amounts 10,000
  USDC and 10,000 USDT (`deal`ed 100,000 of each in setup); the v4 leg passes the
  liquidity computed from those amounts and the pool's current price
  (`LiquidityAmounts.getLiquidityForAmounts`), since `MINT_POSITION` takes liquidity, with
  the same amounts as `amount0Max/amount1Max`. Recipient/owner is the test contract;
  `deadline = block.timestamp`; no receiver hook is invoked on any leg (plain `_mint`).
- Payment: Ekubo Positions pulls via `transferFrom` from `msg.sender` (ERC20 approval to
  Positions); v3 NPM pulls in the pool callback (approval to NPM); v4 PositionManager
  pulls through Permit2 (ERC20 approval to Permit2 plus a `Permit2.approve` allowance to
  the manager). All approvals are granted in setup and never measured. USDT returns no
  returndata, so its approvals are low-level calls.
- Warm-up: one identical, unmeasured mint first. Every mint creates a new NFT, so the
  warm-up is a separate position that initializes the boundary ticks if they were cold
  and makes the minter's NFT balance nonzero; the measured mint is then a new position
  with initialized boundary ticks, the lab condition. On the Ekubo leg the warm-up uses
  `mintAndDepositWithSalt` with an explicit salt: `mint()` derives its salt from
  `prevrandao` and remaining gas, which two identical isolated calls share, so a plain
  repeat reverts with `TokenAlreadyExists`. The measured Ekubo call is the plain
  user-facing `mintAndDeposit`. The v4 tokenId is `nextTokenId()` read before the call.
- Boundary-tick state, checked on-chain before the warm-up: both Uniswap pools already had
  their full-range ticks initialized (`ticks(...).initialized` on v3,
  `getTickLiquidity` on v4); the Ekubo pool had no position at `±88722800`
  (`Core.nextInitializedTick`), so its warm-up figure includes tick initialization and
  the first NFT for the minter. A second test per leg (`*_coldBoundaryTicks`) mints, after
  the same full-range warm-up, a range whose two boundary ticks are asserted
  uninitialized (`±500001` on Uniswap, `±88722750` on Ekubo) and asserted initialized
  afterwards; its figures, like the warm-up figures, are one-time initialization costs,
  recorded in the snapshot files but excluded from the docs page by design.
- Proof of execution, asserted after the measured mint: `ownerOf(id)` is the minter, the
  manager's recorded position liquidity equals the returned liquidity (Ekubo
  `getPositionFeesAndLiquidity`, v4 `getPositionLiquidity`, v3 `positions`), the pool's
  active liquidity equals its value before plus both mints (Ekubo: Core's packed pool
  word; v4 `getLiquidity`; v3 `liquidity()`), and the minter's USDC and USDT balances fall
  by exactly the amounts pulled. The v4 leg also asserts the manager already stored this
  pool key (no first-use pool-key write in the measurement).
- Manager identity, asserted on the fork: v3 NPM `name()` = `Uniswap V3 Positions NFT-V1`
  and `factory()` = the v3 factory; v4 PositionManager `name()` =
  `Uniswap v4 Positions NFT`, `poolManager()` = the PoolManager, `permit2()` = Permit2;
  Ekubo Positions `name()` = `Ekubo Positions`. The Ekubo pool id is re-derived as
  `keccak256(abi.encode(USDC, USDT, config))` and asserted equal to the swap leg's id, and
  Core's packed state at that slot is asserted initialized; the v4 pool id is re-derived
  from the key and asserted equal to the swap leg's id.

| Leg (execution gas)                | Measured (warm, ticks initialized) | Liquidity     | Amount0 USDC  | Amount1 USDT   |
| ---------------------------------- | ---------------------------------- | ------------- | ------------- | -------------- |
| Ekubo Positions `mintAndDeposit`   | 244,513                            | 9,996,041,392 | 9,992,084,352 | 10,000,000,000 |
| v4 PositionManager `MINT_POSITION` | 297,390                            | 9,996,510,484 | 9,993,022,187 | 10,000,000,000 |
| v3 NPM `mint`                      | 381,653                            | 9,996,546,576 | 9,993,094,345 | 10,000,000,000 |

Ekubo tokenId `25083100237766864067710388918595849694396003226932398993912489470024538291565`
(salt-derived), v4 tokenId 405710, v3 tokenId 1365900. The Ekubo figures are not
comparable to the lab Positions NFT figure (213,104): the fork runs against the real USDC
proxy and USDT contracts, not the shared mock token.

Calldata reference files (exact byte counts verified by decoding each file):

| Router call                      | File                                   | Bytes | Zero / nonzero | Calldata gas | EIP-7623 floor |
| -------------------------------- | -------------------------------------- | ----- | -------------- | ------------ | -------------- |
| Ekubo Yul router route           | `calldata-yul-route.hex`               | 184   | 68 / 116       | 2,128        | 5,320          |
| Ekubo Solidity `Router` single   | `calldata-ekubo-solidity-router.hex`   | 132   | 76 / 56        | 1,200        | 3,000          |
| SwapRouter `exactInputSingle`    | `calldata-swaprouter-exactinput.hex`   | 260   | 188 / 72       | 1,904        | 4,760          |
| Universal Router single V3 swap  | `calldata-universal-router-v3swap.hex` | 548   | 464 / 84       | 3,200        | 8,000          |
| Minimal v4 locker (fork harness) | `calldata-v4-minimal-locker.hex`       | 292   | 175 / 117      | 2,572        | 6,430          |

The Yul route and the two Uniswap files are captured production calldata; the Solidity
`Router` and minimal-locker files are the ABI encoding of the same 1000 USDT swap
(`swapAllowPartialFill` on the Ekubo fork pool key, and `ForkSwapRouter.swap` with the
fork test's arguments) and decode back to those arguments with `cast calldata-decode`.
Calldata gas is 4 per zero byte and 16 per nonzero byte; the floor is 10 gas per token
(one per zero byte, four per nonzero byte) and applies only when it exceeds the whole
transaction's regular gas, which it never does here.

## Lab result tables (archived from the docs page)

Steady state unless noted (one identical unmeasured warm-up call first).
Execution gas, net of refunds; v3 rows that earn refunds show net (gross, refund).

Single swaps, cheapest path per protocol (Ekubo production Solidity `Router`,
v4 minimal locker, v3 direct `pool.swap` as an unsendable floor):

| Swap                        | Ekubo  | Uniswap v4 | Uniswap v3                                     |
| --------------------------- | ------ | ---------- | ---------------------------------------------- |
| ERC20 to ERC20              | 87,416 | 103,533    | 87,641                                         |
| ERC20 to ERC20, reverse     | 86,334 | 103,358    | 87,040                                         |
| Native ETH to ERC20         | 72,580 | 88,864     | n/a (pools hold WETH; one `deposit` is 27,938) |
| ERC20 to ERC20, bare locker | 87,077 | 103,533    | n/a (an EOA cannot pay a v3 callback)          |

First swap in a fresh pool, no warm-up (one-time fee-accumulator write on v3/v4):
Ekubo 87,384, v4 120,633, v3 104,741 — exactly 17,100 more on both Uniswap
versions (20,000 gas instead of 2,900 for one zero-to-nonzero write).

Routes through 1/2/3 pools in one transaction (Ekubo production `Router`
multihop entry, single-lock v4 router, SwapRouter-shaped v3 router):

| Pools | Ekubo   | Uniswap v4 | Uniswap v3, net (gross, refund) |
| ----- | ------- | ---------- | ------------------------------- |
| 1     | 94,904  | 107,360    | 94,078 (94,078, 0)              |
| 2     | 119,333 | 141,771    | 152,774 (172,674, 19,900)       |
| 3     | 143,774 | 176,182    | 211,470 (251,270, 39,800)       |

Marginals per extra pool: 24,429 / 24,441 (Ekubo), 34,411 (v4), 58,696 net
(78,596 gross) on v3.

Swap frame attribution, steady-state single (transfers excluded from the core
frame): Ekubo `Core.swap` 20,363 (23%), settlement 37,680 (43%), lock plumbing
29,373 (34%); v4 `PoolManager.swap` 28,884 (28%), settlement 38,024 (37%),
plumbing 36,625 (35%); v3 pool frame 66,430 with internals ~36,800 (39%),
settlement ~29,600 (31%), plumbing 27,648 (29%).

Bare-tier mints (new position, boundary ticks initialized): Ekubo 179,020, v4
162,188, v3 138,380 net (141,180 gross, 2,800 refund); Ekubo Positions NFT
213,104; v3 same-position top-up 121,496 net.

## Pools per swap transaction (mainnet, JSON-RPC)

The docs page's chain-wide blend uses a measured average of pools touched per swap
transaction. Dune was the intended source (a trailing-7-day query over `ethereum.logs`)
but no Dune API key or account was available to this repository, so the measurement was
taken from a public JSON-RPC endpoint instead: `https://ethereum-rpc.publicnode.com`
(`eth_getBlockReceipts` and `eth_getBlockByNumber` with full transactions; that endpoint
refuses `eth_getLogs` without an address filter, so receipts are read per block). The
window is 1,000 consecutive blocks, `25997046` to `25998045` (2026-09-17 11:55:11 to
15:16:11 UTC, tip pinned 12 blocks behind head at start), 2,174 RPC calls in total, no
rate limiting observed at 4 concurrent blocks. Script and raw output:
`pools-per-swap/measure.mjs` and `pools-per-swap/results.json`. An earlier 200-block run
(`25997689`–`25997888`, Uniswap v2/v3/v4 and Curve only) gave 5,341 swap transactions at
1.657 pools per swap and a 30.25% gas share; the wider event set and window below
supersede it.

```sh
cd benchmarks/pools-per-swap
node measure.mjs --blocks 1000 --to 25998045        # reproduces results.json
node measure.mjs --blocks 1000                      # fresh window ending 12 blocks behind head
```

Two measurements are taken over the same blocks:

1. **Receipts (all flow).** A transaction counts as a swap if it succeeded and emitted at
   least one pool-level swap event; its pool count is the number of such events. This
   covers routers, aggregators, MEV bundles and direct pool calls alike. Logs exist only
   for successful transactions, so failed fills are excluded by construction (the script
   keeps a sanity counter for failed transactions with logs; it read 0).
2. **Calldata (router flow only).** For successful transactions sent to the routers
   below, the hop count is decoded from calldata: Universal Router `execute` commands
   (`V3_SWAP_EXACT_IN/OUT` from the `20 + 23n`-byte path, `V2_SWAP_EXACT_IN/OUT` from
   `path.length − 1`, `V4_SWAP` from the single/multi swap actions and `PathKey[]`
   length), SwapRouter02 and classic SwapRouter `exactInput/exactOutput` paths and their
   `Single` variants (1 pool), including inside `multicall`, Uniswap v2 Router02 `swap*`
   paths, and 1inch v6 `unoswap/unoswap2/unoswap3` (1/2/3 pools by construction). 1inch's
   generic `swap(executor, desc, data)` carries its route inside opaque executor data and
   is reported as "opaque"; the remaining undecoded 1inch selectors were limit-order calls
   (`cancelOrder` 0xb68fb020 alone is 239 of the 323 undecoded transactions, then
   `fillContractOrder(Args)`, `permitAndCall`), not swaps. Every decoded router transaction
   is cross-checked against its own receipt (see the router table).

### Event set

Every signature was read from the protocol's own source file (path in the table) and
hashed with `cast keccak` (Foundry 1.8.3); nothing was taken from memory.

| Family                   | Source                                                                             | Event                                                                                   | topic0                        |
| ------------------------ | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | ----------------------------- |
| Uniswap v3               | Uniswap/v3-core `IUniswapV3PoolEvents.sol`                                         | `Swap(address,address,int256,int256,uint160,uint128,int24)`                             | `0xc42079f9…`                 |
| Uniswap v2 family        | Uniswap/v2-core `IUniswapV2Pair.sol`                                               | `Swap(address,uint256,uint256,uint256,uint256,address)`                                 | `0xd78ad95f…`                 |
| Uniswap v4               | Uniswap/v4-core `IPoolManager.sol`                                                 | `Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)`                      | `0x40e9cecb…`                 |
| PancakeSwap v3           | pancakeswap/pancake-v3-contracts `IPancakeV3PoolEvents.sol`                        | `Swap(address,address,int256,int256,uint160,uint128,int24,uint128,uint128)`             | `0x19b47279…`                 |
| Curve (stable)           | curvefi/stableswap-ng `CurveStableSwapNG.vy` (same as the classic pools)           | `TokenExchange(address,int128,uint256,int128,uint256)`                                  | `0x8b3e96f2…`                 |
| Curve (stable, meta)     | same                                                                               | `TokenExchangeUnderlying(address,int128,uint256,int128,uint256)`                        | `0xd013ca23…`                 |
| Curve (crypto v2)        | curvefi/curve-crypto-contract `CurveCryptoSwap2ETH.vy`                             | `TokenExchange(address,uint256,uint256,uint256,uint256)`                                | `0xb2e76ae9…`                 |
| Curve (tricrypto/two-ng) | curvefi/tricrypto-ng `CurveTricryptoOptimizedWETH.vy`, twocrypto-ng `Twocrypto.vy` | `TokenExchange(address,uint256,uint256,uint256,uint256,uint256,uint256)`                | `0x143f1f8e…`                 |
| Balancer v2              | balancer/balancer-v2-monorepo `vault/IVault.sol`                                   | `Swap(bytes32,address,address,uint256,uint256)`                                         | `0x2170c741…`                 |
| Balancer v3              | balancer/balancer-v3-monorepo `vault/IVaultEvents.sol`                             | `Swap(address,address,address,uint256,uint256,uint256,uint256)`                         | `0x0874b2d5…`                 |
| Maverick v1              | maverickprotocol/maverick-v1-interfaces `IPool.sol`                                | `Swap(address,address,bool,bool,uint256,uint256,int32)`                                 | `0x3b841dc9…`                 |
| Maverick v2              | maverickprotocol/v2-common `IMaverickV2Pool.sol`                                   | `PoolSwap(address,address,(uint256,bool,bool,int32),uint256,uint256)`                   | `0x103ed084…`                 |
| Fluid DEX                | Instadapp/fluid-contracts-public `dex/poolT1/coreModule/events.sol`                | `Swap(bool,uint256,uint256,address)`                                                    | `0xdc004dbc…`                 |
| DODO v2 (DVM/DPP/DSP)    | DODOEX/contractV2 `DVMTrader.sol`, `DPPTrader.sol`, `DSPTrader.sol`                | `DODOSwap(address,address,uint256,uint256,address,address)`                             | `0xc2c0245e…`                 |
| DODO v1                  | DODOEX/dodo-smart-contract `impl/Trader.sol`                                       | `SellBaseToken(address,uint256,uint256)` / `BuyBaseToken(address,uint256,uint256)`      | `0xd8648b6a…` / `0xe93ad760…` |
| Bancor v3                | bancorprotocol/contracts-v3 `network/BancorNetwork.sol`                            | `TokensTraded(bytes32,address,address,uint256,uint256,uint256,uint256,uint256,address)` | `0x5c02c2bb…`                 |
| Bancor Carbon            | bancorprotocol/carbon-contracts `carbon/Strategies.sol`                            | `TokensTraded(address,address,address,uint256,uint256,uint128,bool)`                    | `0x95f3b013…`                 |
| Bancor v2.1              | bancorprotocol/contracts-solidity `converter/interfaces/IConverter.sol`            | `Conversion(address,address,address,uint256,uint256,int256)`                            | `0x276856b3…`                 |
| Solidly-style pairs      | aerodrome-finance/contracts `interfaces/IPool.sol`                                 | `Swap(address,address,uint256,uint256,uint256,uint256)`                                 | `0xb3e27736…`                 |
| Ekubo                    | EkuboProtocol/evm-contracts v3.2.0 `src/Core.sol`                                  | `log0`, no topics, 116 bytes (locker, poolId, balanceUpdate, stateAfter)                | none                          |

Full hashes are in `measure.mjs` and `results.json`. Notes on folding and coverage:

- The v2 signature is shared by Uniswap v2, SushiSwap, PancakeSwap v2, Fraxswap and every
  other v2 fork, so those are one "v2 family" and cannot be separated by event alone.
  The v3 signature is likewise shared by SushiSwap v3 and KyberSwap Elastic (identical
  parameter types), so those land in the v3 row. Solidly-style pairs (Aerodrome,
  Velodrome) hash to a different topic and were added, but emitted nothing on mainnet in
  the window (they live on Base and Optimism).
- Curve's four exchange events are folded into one family. PancakeSwap v3 is a separate
  row because its `Swap` carries two extra protocol-fee words and therefore a different
  topic.
- Ekubo Core writes its swap record with `log0` and no topics (`Core.sol`,
  `log0(o, 116)`), so topic filtering cannot see it. It is counted instead as "a
  topic-less log from the Core address with exactly 116 bytes of data"; every other
  Core event is a normal topic-carrying `emit`, and the sanity counter for topic-less
  Core logs of any other length read 0. This counts every Ekubo swap regardless of
  caller. The production Yul router (`0x7B2aA7Ec…`, bytecode verified to embed the Core
  address) received 1 transaction in the window; Ekubo flow arrives through 1inch, 0x,
  Relay, Kyber and other aggregators. Hop counts are not decoded from the Yul router's
  packed calldata. The legacy Ekubo v2 core (`0xe0e0e08A…`) is not counted.
- Within the Balancer v2 family, 58 of the 243 transactions came from a second
  `Vault` deployment (`0xd315a9c3…`, Sourcify exact match to `contracts/Vault.sol`), a
  Balancer-v2-architecture fork; it is left in the family.

Not counted, and why:

- Order-flow and RFQ settlement that is not a pool: CoW Protocol, UniswapX, 1inch and
  KyberSwap limit orders (`DSLOProtocol`), 0x RFQ fills. Their transactions are counted
  only when a leg lands in one of the pools above. The KyberSwap router transactions
  without any counted event (51 in the first 200 blocks) were limit-order fills.
- Long-tail AMMs outside the set (Kyber Classic/DMM, Smardex, Integral, Shell, Uniswap v1,
  DODO v3): no signature was verified from source for them within the time box.
- One unidentified contract (`0xf2e3dcb8…`) that emits topic-less logs (29 transactions,
  5.2M gas in the first 200 blocks, no verified source on Sourcify).
- Everything the discovery scan identified as non-AMM: ERC-4337 EntryPoint and
  paymasters, Aave, Morpho, bridges (Relay, LiFi, Optimism/Base messengers), the Aztec
  rollup, Seaport, Chainlink VRF, batch-transfer and address-poisoning contracts.

Router addresses were not taken from memory: at startup the script fetches each
contract's bytecode and aborts unless it contains the listed function selectors (or,
for the selector-less Yul router, the Core address).

| Router                             | Address                                      | Verified in bytecode                                 |
| ---------------------------------- | -------------------------------------------- | ---------------------------------------------------- |
| Universal Router (v2, 2025)        | `0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af` | `execute` `0x3593564c`                               |
| Universal Router (v1.2, 2023)      | `0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD` | `execute` `0x3593564c`                               |
| Universal Router (2026 deployment) | `0x4c82d1FBfe28c977cbb58d8c7ff8FcF9f70a2cca` | `execute` `0x3593564c` (Sourcify: `UniversalRouter`) |
| SwapRouter02                       | `0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45` | `exactInput` `0xb858183f`, `multicall` `0x5ae401dc`  |
| SwapRouter (v3 classic)            | `0xE592427A0AEce92De3Edee1F18E0157C05861564` | `exactInput` `0xc04b8d59`                            |
| Uniswap v2 Router02                | `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D` | `swapExactTokensForTokens` `0x38ed1739`              |
| 1inch AggregationRouter v6         | `0x111111125421cA6dc452d289314280a0f8842A65` | `swap` `0x07ed2379`, `unoswap` `0x83800a8e`          |
| Ekubo Yul router                   | `0x7B2aA7Ecc0B5936b7C52E6259A19C3BA557d0748` | Core address `0x…14aA86C5d3c41765bb24e11bd701`       |

### Results (blocks 25997046–25998045)

All flow, from receipts: 321,702 transactions in the window (317,617 successful), of
which 32,417 are swap transactions with 54,407 pool swap events,
**1.678 pools per swap transaction** (54,407 / 32,417 = 1.6783).

| Pools touched | Transactions | Share  |
| ------------- | ------------ | ------ |
| 1             | 23,358       | 72.05% |
| 2             | 4,801        | 14.81% |
| 3             | 2,027        | 6.25%  |
| 4 or more     | 2,231        | 6.88%  |

Per family (a transaction touching two families is counted in both; "gas" is the gas of
every transaction touching the family, so it also overlaps):

| Family            | Transactions | Events | Events of this family per tx | All pools per tx touching it | Gas of those txs | Emitting contracts |
| ----------------- | ------------ | ------ | ---------------------------- | ---------------------------- | ---------------- | ------------------ |
| Uniswap v3        | 15,900       | 21,418 | 1.347                        | 2.024                        | 5,672,233,165    | 813                |
| Uniswap v4        | 11,748       | 17,467 | 1.487                        | 2.354                        | 4,741,053,798    | 1 (PoolManager)    |
| Uniswap v2 family | 7,528        | 8,963  | 1.191                        | 2.128                        | 2,467,266,054    | 1,267              |
| Curve             | 1,652        | 2,250  | 1.362                        | 4.079                        | 1,286,127,611    | 219                |
| PancakeSwap v3    | 1,307        | 1,433  | 1.096                        | 4.111                        | 858,951,131      | 35                 |
| Ekubo             | 943          | 1,079  | 1.144                        | 3.538                        | 673,692,276      | 1 (Core)           |
| Fluid DEX         | 551          | 587    | 1.065                        | 3.316                        | 435,123,007      | 19                 |
| DODO              | 421          | 448    | 1.064                        | 4.496                        | 399,393,841      | 56                 |
| Balancer v2       | 243          | 259    | 1.066                        | 4.066                        | 160,357,147      | 2 (Vault + fork)   |
| Balancer v3       | 202          | 226    | 1.119                        | 5.119                        | 204,734,020      | 2                  |
| Maverick v2       | 118          | 123    | 1.042                        | 5.127                        | 117,418,379      | 7                  |
| Bancor v2.1       | 54           | 107    | 1.981                        | 6.130                        | 42,174,657       | 19                 |
| Bancor v3         | 23           | 23     | 1.000                        | 5.348                        | 17,867,787       | 1                  |
| Maverick v1       | 17           | 18     | 1.059                        | 6.059                        | 12,229,328       | 7                  |
| Bancor Carbon     | 6            | 6      | 1.000                        | 2.333                        | 3,788,965        | 1                  |
| Solidly-style     | 0            | 0      | —                            | —                            | —                | 0                  |

Reading the right-hand columns: the families added in this pass are mostly reached
through aggregators (a transaction touching Balancer v3 averages 5.1 pools in total,
Maverick v2 5.1, Curve 4.1), while the four families of the first run are where the
single-pool retail flow lives. Adding them therefore raised the average from 1.657 to
1.678, not by more.

Gas: the swap transactions used 10,039,217,633 of the window's 30,729,852,504 gas,
**32.67%**. This is the gas of whole transactions that contain a swap event (an
aggregator's or MEV bot's overhead included), so it is an upper bound on swap gas and a
direct check on the router-address-only burn share (4.2%), which it comfortably exceeds.

Router flow only, from calldata: 4,432 decoded transactions, 5,687 pools,
**1.283 pools per swap**; 444 opaque (443 1inch generic `swap`, 1 Ekubo Yul
router), 323 undecoded (limit-order and liquidity calls, see above), 284 failed
(excluded).

| Pools touched | Transactions | Share  |
| ------------- | ------------ | ------ |
| 1             | 3,712        | 83.75% |
| 2             | 473          | 10.67% |
| 3             | 130          | 2.93%  |
| 4 or more     | 117          | 2.64%  |

| Router                             | Decoded txs | Avg pools | 1 / 2 / 3 / 4+       | Calldata = events |
| ---------------------------------- | ----------- | --------- | -------------------- | ----------------- |
| SwapRouter02                       | 1,168       | 1.076     | 1093 / 71 / 0 / 4    | 1,168 / 1,168     |
| Universal Router (v2, 2025)        | 1,153       | 1.207     | 974 / 147 / 18 / 14  | 1,150 / 1,153     |
| Universal Router (2026 deployment) | 1,070       | 1.837     | 635 / 224 / 112 / 99 | 1,056 / 1,070     |
| Uniswap v2 Router02                | 658         | 1.011     | 651 / 7 / 0 / 0      | 650 / 658         |
| SwapRouter (v3 classic)            | 281         | 1.036     | 271 / 10 / 0 / 0     | 281 / 281         |
| Universal Router (v1.2, 2023)      | 70          | 1.000     | 70 / 0 / 0 / 0       | 70 / 70           |
| 1inch v6 `unoswapN`                | 32          | 1.438     | 18 / 14 / 0 / 0      | 32 / 32           |

In 4,407 of the 4,432 decoded transactions the calldata hop count equals the event count.
The 25 exceptions all have more events than hops, never fewer: Universal Router
transactions whose Uniswap v4 legs went through hook pools that perform a nested
`PoolManager` swap (17, e.g. 1 hop decoded / 2 `Swap` events, 11 / 16, 3 / 8), and v2
Router02 `swapExactTokensForTokensSupportingFeeOnTransferTokens` calls on tax tokens
that sell their fee through the same pair inside the transfer (8, each 1 hop / 2
events on one pair). Both are real extra pool swaps, so the receipts measurement keeps
them; note that it counts swap events, not distinct pools, so a pool swapped twice in
one transaction counts twice.

The gap between 1.68 (all flow) and 1.28 (router flow) is the multi-pool weight of
aggregators, solvers, MEV bundles and other contract callers. The docs page uses the
all-flow figure as its headline blend and shows the router-only figure as context.

Caveats: 1,000 blocks is about three and a half hours of one day, not a 7-day window;
the distribution should be re-run over a longer window (the script accepts `--blocks`)
before being quoted as a long-run figure. The event set now covers every AMM family
found among the window's gas consumers; what remains uncounted is listed under "Not
counted" above, so a transaction whose only swap is an order-book fill, a legacy Ekubo
v2 swap, or a long-tail AMM is not counted.

## Dependency pins

- Ekubo `evm-contracts` worktree at commit `1f5be49` (plus the harness test files
  in this directory); `forge-std` `77041d2`, `solady` `65e87c7`; solc `0.8.33`,
  `optimizer_runs = 9999999`, `via_ir`, `evm_version = "osaka"`.
- Uniswap `v4-core` commit `46c6834`; solc `0.8.26`,
  `optimizer_runs = 44444444`, `via_ir`, `evm_version = "cancun"`
  (v4-core's own `foundry.toml`).
- Uniswap `v3-core` `1.0.1` canonical mainnet bytecode
  (`@uniswap/v3-core` npm artifacts, `UniswapV3Factory.json`); the harness driver
  compiles with solc `0.8.26`, `evm_version = "cancun"`.
- Fork harness: `evm_version = "osaka"` for all three legs, solc auto-detected per file.
- Shared token: solmate `MockERC20` bytecode in `lab/MockERC20.json`.
- Yul router SDK (`ekubo/yul-router`) for the fork calldata generation.
- Foundry `1.8.3`.

## Reproducing the lab numbers

```sh
# v4 (from a checkout of Uniswap/v4-core@46c6834 with submodules initialized)
forge test --match-contract V4GasTest

# ekubo (remap ekubo/, forge-std/, solady/ at the pins above, deployCode the token)
forge test --offline --match-contract EkuboGasTest

# v3 (needs UniswapV3Factory.json next to MockERC20.json under artifacts/)
forge test --match-contract V3GasTest

# flamegraphs (one per harness)
forge test --match-contract FlameTest --flamegraph --no-open
```

Run a whole test contract at a time: Foundry rewrites `snapshots/<Contract>.json` with
only the tests that ran.

## Reproducing the fork numbers

```sh
forge test --fork-url <mainnet-rpc> --fork-block-number 25991868 \
  --match-contract 'ForkEkuboRealTest|ForkV3Test|ForkV4Test|ForkProbeTest'

# mints through the production position managers (one contract at a time keeps
# each snapshot file complete; add retries/backoff for rate-limited public RPCs)
forge test --fork-url <mainnet-archive-rpc> --fork-block-number 25991868 \
  --fork-retries 10 --fork-retry-backoff 2000 \
  --match-contract 'ForkMintEkuboTest|ForkMintV3Test|ForkMintV4Test' -vv
```

The block needs an archive-capable endpoint. The swap legs were captured through
`https://ethereum-rpc.publicnode.com` while the block was inside its recent-state window;
the mint legs were run later against `https://eth-mainnet.public.blastapi.io` (publicnode
had by then started refusing the block as an archive request). Both serve the same
canonical state, which the assertions on pool identity, price and manager wiring confirm.

Deployed addresses used (all verified on-chain, none memorized):

| Contract                                                                            | Address                                      |
| ----------------------------------------------------------------------------------- | -------------------------------------------- |
| Ekubo Core                                                                          | `0x00000000000014aA86C5d3c41765bb24e11bd701` |
| Ekubo Yul router (production)                                                       | `0x7B2aA7Ecc0B5936b7C52E6259A19C3BA557d0748` |
| Uniswap v4 PoolManager                                                              | `0x000000000004444c5dc75cB358380D2e3dE08A90` |
| Uniswap v3 SwapRouter (classic)                                                     | `0xE592427A0AEce92De3Edee1F18E0157C05861564` |
| Uniswap v3 factory                                                                  | `0x1F98431c8aD98523631AE4a59f267346ea31F984` |
| Ekubo Positions (canonical, original generation; docs contracts reference)          | `0x02D9876A21AF7545f8632C3af76eC90b5ad4b66D` |
| Uniswap v4 PositionManager (docs.uniswap.org/contracts/v4/deployments, Ethereum: 1) | `0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e` |
| Permit2                                                                             | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |
| Uniswap v3 NonfungiblePositionManager                                               | `0xC36442b4a4522E871399CD717aBDD847Ab11FE88` |
| WETH                                                                                | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` |
| USDC                                                                                | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| USDT                                                                                | `0xdAC17F958D2ee523a2206206994597C13D831ec7` |

The v3/v4 fork pools (USDT/USDC fee-100, deepest at the pinned block) were selected by
on-chain probing (`ForkProbe.t.sol`, which also reads the Ekubo pool state directly from
Core storage); the Ekubo pool came from the production quoter.
