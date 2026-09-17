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
