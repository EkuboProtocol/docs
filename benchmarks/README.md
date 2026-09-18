# Gas benchmark harnesses

Foundry tests behind the numbers on the [Gas efficiency](/reference/gas-efficiency/) page.
Each protocol compiles under its own production toolchain settings, so the comparison
measures code and architecture rather than compiler tuning.

## Layout

- `lab/ekubo/` — Ekubo EVM swaps, mints and pool initialization (`EkuboGas.t.sol`, plus
  `Flame.t.sol` for the single-call flamegraph capture)
- `lab/v4/` — Uniswap v4 (`V4Gas.t.sol`, `Flame.t.sol`)
- `lab/v3/` — Uniswap v3 (`V3Gas.t.sol`, `Flame.t.sol`)
- `lab/MockERC20.json` — the single shared token artifact deployed via `deployCode`
  in all three lab harnesses, so ERC20 transfer costs cannot skew the comparison
- `prod/` — the headline bench: production Ekubo, Uniswap v3 and Uniswap v4 contracts on
  a fork of the latest mainnet block with fresh ERC20 tokens (`test/Prod*.t.sol`,
  `snapshots/*.json`, `calldata/*.hex` with the exact bytes of every measured call,
  `encode-prod-routes.mjs` for the SDK routes, `run.sh`); see "Production-contract bench"
  below
- `pools-per-swap/` — the pools-touched-per-swap-transaction measurement behind the
  chain-wide section (`measure.mjs`, `results.json` for the 1,000-block window,
  `results-30d.json` for the 30-day stride sample); see below
- `fork/` — mainnet-fork validation at pinned block `25991868`
  (`ForkEkuboReal.t.sol`, `ForkV3.t.sol`, `ForkV4.t.sol` for swaps;
  `ForkMintEkubo.t.sol`, `ForkMintV3.t.sol`, `ForkMintV4.t.sol` for mints through the
  production position managers; `ForkProbe.t.sol` for the pool identifiers;
  `calldata-*.hex` reference calldata, `encode-yul-route.mjs`)
- `fork-l2/` — Base and Arbitrum One fork swaps (`ForkL2Ekubo.t.sol`, `ForkL2V3.t.sol`,
  `ForkL2V4.t.sol`, one snapshot JSON per test contract, `calldata/*.hex` with the exact
  bytes of every measured call, `encode-l2-routes.mjs` for the SDK routes,
  `l1-data-cost.mjs` and its raw output `l1-data-cost.json` for the L1 data component,
  `quote-live-base.mjs`); see "L2 fork methodology" below

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

## Production-contract bench (`prod/`)

The page's headline and route-scaling numbers. Every contract that executes a measured
call is the deployed production one on Ethereum mainnet, read from a fork of the latest
block at run time (`run.sh`; no block pin, so the bench reproduces on any day — the
committed snapshots record the block they were taken at, `prod fork block number`
25999935, timestamp 1789680959, 2026-09-17 21:35:59 UTC). Only the tokens are new:

- **Tokens.** Four fresh solmate `MockERC20` contracts (the lab artifact,
  `artifacts/MockERC20.json`) etched at fixed, address-ordered addresses
  `0x1111…1111` (A) `< 0x2222…2222` (B) `< 0x3333…3333` (C) `< 0x4444…4444` (D), asserted
  codeless on the chain before etching. Fixed addresses make the SDK route calldata
  reproducible; all-nonzero bytes make it pay the full 16 gas per address byte (a real
  address has about one zero byte in 256, so this is marginally pessimistic for every
  leg alike). Plain ERC20 transfers, no proxy, no blocklist, no fee-on-transfer: the
  USDC/USDT fork numbers below keep the expensive-token case.
- **Contracts.** Ekubo Core `0x00000000000014aA86C5d3c41765bb24e11bd701`, Positions
  `0x02D9876A21AF7545f8632C3af76eC90b5ad4b66D` (asserted `name() == "Ekubo Positions"`),
  Yul router `0x7B2aA7Ecc0B5936b7C52E6259A19C3BA557d0748`; Uniswap v3 factory
  `0x1F98431c8aD98523631AE4a59f267346ea31F984` and SwapRouter
  `0xE592427A0AEce92De3Edee1F18E0157C05861564` (asserted `factory()` and `WETH9()`);
  Uniswap v4 PoolManager `0x000000000004444c5dc75cB358380D2e3dE08A90`, Universal Router
  `0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af` and Permit2
  `0x000000000022D473030F116dDEE9F6B43aC78BA3`. Every address is checked for code on the
  fork; the Ekubo addresses are the ones in the docs' EVM contract reference.
- **Pools.** A/B, B/C, C/D and a native pool ETH/B on each protocol, 0.3% fee, Uniswap
  tick spacing 60 (Ekubo spacing 6000; its ticks are 100x finer), initialized strictly
  inside a tick (Uniswap tick 30, Ekubo tick 3050 = Uniswap 30.5, so Ekubo's pools sit
  0.005% higher and its outputs are 0.005% larger; irrelevant to gas). One full-range
  position per pool of the liquidity that 1M tokens a side buys at that price
  (v3 mints the same liquidity figure as the lab, 998501199320305883812938). Ekubo pools
  are asserted uninitialized on the fork before creation; Uniswap pools are asserted
  absent from the factory / PoolManager. Capitalization is unmeasured: Ekubo through the
  production Positions manager (`mintAndDepositWithSalt` with explicit salts — the
  deployed manager's `mintAndDeposit` derives its salt from prevrandao and remaining
  gas, which back-to-back mints in one context share), v3 by a direct `pool.mint` with
  the test as callback payer, v4 through v4-core's `PoolModifyLiquidityTest`.
- **Isolation and warmth.** Every measured call is a top-level call from the test under
  `isolate = true`, so `vm.snapshotGasLastCall` is that call's execution gas net of
  refunds, excluding the 21,000 base and calldata. One identical, unmeasured call
  precedes every measurement, so every storage slot the swap touches is already nonzero
  (pool state, both fee-growth accumulators, the recipient's output balance, which is
  asserted nonzero before the measured call, and the router's approvals). Pool creation,
  tick initialization, first-swap accumulator writes and NFT mints are therefore
  excluded by design. Every measured swap is exact-input 1 token; the last pool's tick is
  asserted to move by at most one Uniswap tick (measured: 0 on Uniswap, 2 fine ticks =
  0.02 Uniswap ticks on Ekubo), and the router's reported output is asserted equal to
  the recipient's balance change.
- **Calldata.** The exact bytes of every measured call are written to `calldata/*.hex`
  and recorded in the snapshot as byte count, EIP-2028 gas (4 per zero byte, 16 per
  nonzero byte) and EIP-7623 floor tokens; the floor never binds here (execution is far
  above it). Transaction gas on the page = snapshot + 21,000 + EIP-2028 calldata gas.
- **Paths.** Two tiers per protocol. Production routers: the Ekubo Yul router with
  SDK-generated routes (`encode-prod-routes.mjs`, 184 / 273 / 362 bytes for 1 / 2 / 3
  pools), the v3 SwapRouter (`exactInputSingle`, `exactInput` with a packed path; the
  native leg sends ETH to the router, which wraps it in flight), and the v4 Universal
  Router (`execute` with one `V4_SWAP` command: `SWAP_EXACT_IN_SINGLE`, `SETTLE_ALL`,
  `TAKE_ALL`, funded through Permit2 with a standing allowance granted in setup; the
  `ExactInputSingleParams` layout is the 2025 deployment's, without `minHopPriceX36`,
  confirmed by the call succeeding with the same output as the minimal locker to 1e-15).
  Minimal single-lock routers: array-based N-hop lockers of the same shape on all three
  sides (`MinimalEkuboRouter`: lock, swap each hop, pay once, withdraw once;
  `V4MinimalRouter`: unlock, swap each hop, settle once, take once; `V3MinimalRouter`:
  the SwapRouter's token flow with 2 transfers per pool). Minimal routers favor
  Uniswap: its production routers cost more than the minimal figures, while Ekubo's
  production Yul router is cheaper than its minimal locker.

| Leg (execution gas)                    | 1 pool  | 2 pools | 3 pools | Native ETH in, 1 pool | Calldata bytes (1 / 2 / 3 pools) |
| -------------------------------------- | ------- | ------- | ------- | --------------------- | -------------------------------- |
| Ekubo, production Yul router           | 87,663  | 109,850 | 132,025 | 73,764                | 184 / 273 / 362                  |
| Ekubo, minimal locker                  | 89,733  | 112,843 | 135,952 | 74,585                | 260 / 356 / 452                  |
| Uniswap v4, Universal Router + Permit2 | 117,114 | —       | —       | —                     | 1,092                            |
| Uniswap v4, minimal locker             | 107,384 | 141,795 | 176,206 | 92,472                | 356 / 548 / 740                  |
| Uniswap v3, SwapRouter                 | 100,299 | 165,719 | 230,478 | 103,504 (wraps ETH)   | 260 / 324 / 324                  |
| Uniswap v3, minimal router             | 94,078  | 152,774 | 211,470 | —                     | 260 / 324 / 388                  |

Marginal execution gas per extra pool (2→3 pools): Ekubo Yul 22,175 (1→2: 22,187),
Ekubo minimal 23,109, v4 minimal 34,411, v3 minimal 58,696, v3 SwapRouter 64,759
(1→2: 65,420). The v3 minimal-router figures equal the lab harness's to the gas unit
(94,078 / 152,774 / 211,470), which ties the two benches together. Outputs: Ekubo
1000042490223401887 / 1000084982120610903 / 1000127475691875278 wei for 1 / 2 / 3
pools, Uniswap v3 999992341035506990 / 999984682148650249 / 999977023339428738, v4
999992341035507518 / 999984682148651304 / 999977023339430321 (the 0.005% Ekubo
premium is the half-tick higher init price).

Dependencies (`lib/`, git-ignored): forge-std, solady, `EkuboProtocol/evm-contracts` at
`v3.2.0` as `lib/ekubo` (with its own `lib/forge-std` and `lib/solady`), `Uniswap/v4-core`
(with its `lib/solmate`); `remappings.txt` lists the mapping. Foundry 1.8.3, solc
auto-detected per file (0.8.26 for the Uniswap-side tests, 0.8.33 for the Ekubo test),
`via_ir`, 1,000,000 optimizer runs, `evm_version = "osaka"`.

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
transaction. Dune was the intended source (a query over `ethereum.logs`) but no Dune API
key or account was available to this repository, so the measurement is taken from public
JSON-RPC endpoints instead (`eth_getBlockReceipts` and `eth_getBlockByNumber` with full
transactions, read per block). The page uses the **30-day stride sample** below
(`results-30d.json`): every 10th block from `25783810` to `25999800`, 21,600 blocks
read out of the 215,991 spanned (2026-08-18 18:36:47 to 2026-09-17 21:08:59 UTC, tip
pinned 12 blocks behind head at start), so every hour of the month, every day of the
week and every gas regime in it is sampled uniformly. The earlier 1,000-consecutive-block
window `25997046`–`25998045` (`results.json`, 2026-09-17 11:55:11 to 15:16:11 UTC) and a
200-block run before it (Uniswap v2/v3/v4 and Curve only, 1.657 pools per swap) are kept
as the short-window cross-checks; the 30-day sample supersedes both.

```sh
cd benchmarks/pools-per-swap
node measure.mjs --blocks 21600 --stride 10 --to 25999800 --conc 6 --out results-30d.json   # the 30-day sample
node measure.mjs --blocks 1000 --to 25998045                                                 # the 1,000-block window
node measure.mjs --blocks 21600 --stride 10                                                  # a fresh month ending 12 blocks behind head
```

Endpoints for the 30-day run (rotated per request on any failure; `--rpc` overrides):
`https://eth.drpc.org`, `https://mainnet.gateway.tenderly.co`, `https://eth.merkle.io`,
`https://eth.rpc.blxrbdn.com`. `ethereum-rpc.publicnode.com`, used for the 1,000-block
window, returns `null` receipts for blocks older than a few days and cannot serve a
month. Every block is accepted only when the receipt list has exactly one entry per
transaction in the block, in order, with matching hashes; otherwise both calls are
retried on the next endpoint. The run made 54,013 RPC calls, 10,803 of them retries
(rate limiting and one endpoint intermittently answering with empty or partial receipt
lists, which the consistency check rejects), at 6 concurrent blocks in about 100 minutes.

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

### Results, 30-day stride sample (every 10th block, 25783810–25999800)

All flow, from receipts: 5,724,722 transactions in the sampled blocks (5,643,974
successful), of which 664,726 are swap transactions with 1,161,778 pool swap events,
**1.748 pools per swap transaction** (1,161,778 / 664,726 = 1.7478). The swap transactions used
32.68% of all gas in the sampled blocks (the ratio of summed `gasUsed`, so it is the
share of block space, not of fee burn).

| Pools touched | Transactions | Share  |
| ------------- | ------------ | ------ |
| 1             | 459,356      | 69.10% |
| 2             | 106,197      | 15.98% |
| 3             | 49,247       | 7.41%  |
| 4 or more     | 49,926       | 7.51%  |

Per family (a transaction touching two families is counted in both; "gas share" is the
gas of every transaction touching the family over all gas in the sampled blocks, so it
also overlaps):

| Family            | Transactions | Events of this family per tx | All pools per tx touching it | Gas share of window |
| ----------------- | ------------ | ---------------------------- | ---------------------------- | ------------------- |
| Uniswap v3        | 327,953      | 1.327                        | 2.101                        | 18.30%              |
| Uniswap v4        | 237,383      | 1.507                        | 2.493                        | 15.51%              |
| Uniswap v2 family | 178,611      | 1.241                        | 2.212                        | 9.50%               |
| Curve             | 37,104       | 1.391                        | 4.086                        | 4.61%               |
| PancakeSwap v3    | 30,611       | 1.140                        | 4.299                        | 3.23%               |
| Ekubo             | 21,419       | 1.128                        | 3.346                        | 2.22%               |
| Fluid DEX         | 8,789        | 1.079                        | 3.940                        | 1.16%               |
| DODO              | 7,846        | 1.071                        | 4.457                        | 1.08%               |
| Balancer v2       | 5,584        | 1.063                        | 4.230                        | 0.61%               |
| Balancer v3       | 3,987        | 1.080                        | 4.385                        | 0.53%               |
| Maverick v2       | 2,591        | 1.045                        | 4.116                        | 0.33%               |
| Bancor v2.1       | 2,359        | 1.848                        | 5.242                        | 0.25%               |
| Maverick v1       | 563          | 1.046                        | 4.417                        | 0.08%               |
| Bancor v3         | 531          | 1.047                        | 5.633                        | 0.06%               |
| Bancor Carbon     | 218          | 1.009                        | 2.844                        | 0.02%               |
| Solidly-style     | 3            | 1.000                        | 1.667                        | 0.00%               |

Every catalogued family had at least one event in the month; none is missing. The
sanity counters read 0 failed transactions with swap logs and 0 topic-less Core logs of
a length other than 116 bytes.

Per UTC day (`daily` in `results-30d.json`, 716–718 sampled blocks per full day; the
first and last days are partial): the average ranged from 1.640 (August 26) to 1.865
(August 19) pools per swap transaction, and the swap-transaction gas share from 20.25%
(the 162-block partial first day) and 24.82% (August 29) to 41.03% (August 23). The
1,000-block window on September 17 (1.678, 32.67%) sits inside both ranges.

Router flow, from calldata: 135,167 successful transactions to the verified routers were
decoded (8,303 opaque 1inch `swap` calls and 4,224 non-swap selectors excluded) at
**1.219 pools per router transaction**; cross-checked against their own receipts,
134,178 agree exactly, 989 have more pool events than the calldata declares (aggregator
executors adding hops) and none fewer. Direct router calls are lighter than the all-flow
average because aggregators, MEV bundles and other contracts carry most of the multi-pool
weight.

Reading the histogram for the page: 69% of swap transactions touch one pool, but the
31% that touch more carry enough pools to lift the mean to 1.75, and the daily mean
never left the 1.64–1.87 band in a month that spanned a 2x range of swap gas share.

Both the pools-per-swap average and the gas share are lower bounds. A transaction is
counted, and its pools are counted, only through swap events of the catalogued
families; any AMM outside the catalogue (long-tail forks with their own event
signatures, order-book fills that never touch a pool, the legacy Ekubo v2 core)
contributes uncounted transactions, uncounted pools inside counted transactions, and
uncounted gas. The chain-wide capacity figures on the page therefore understate the
effect of moving swap flow to Ekubo.

## L2 fork methodology (Base, Arbitrum One)

Same discipline as the mainnet fork (pinned block, one identical unmeasured warm-up swap,
every measured call isolated, snapshot = execution gas of the measured call net of refunds,
excluding the 21,000 base and calldata), on two L2s whose fee structure differs from
mainnet: cheap L2 execution plus a separate charge for the L1 data the sequencer posts.
Harness, snapshots, exact calldata and the fee-oracle readings are in `fork-l2/`.

### Deployment check

Chain IDs and code presence were read from the public RPCs before anything was pinned
(`cast chain-id`, `cast code`, September 17, 2026). Both chains answer `8453` and `42161`
respectively. Every address below has code on both chains at the pinned blocks; nothing
listed here was taken from memory.

| Contract                                                 | Base (8453)                                  | Arbitrum One (42161)                         | Source                                  |
| -------------------------------------------------------- | -------------------------------------------- | -------------------------------------------- | --------------------------------------- |
| Ekubo Core                                               | `0x00000000000014aA86C5d3c41765bb24e11bd701` | same                                         | docs `reference/contracts/evm-v3`       |
| Ekubo Yul router (production, v0.7.1)                    | `0x7B2aA7Ecc0B5936b7C52E6259A19C3BA557d0748` | same                                         | `yul-router/broadcast/deployments.json` |
| Ekubo Positions (original generation, canonical on both) | `0x02D9876A21AF7545f8632C3af76eC90b5ad4b66D` | same                                         | docs `reference/contracts/evm-v3`       |
| Ekubo Positions (192-bit generation, also deployed)      | `0xA2971E0C37cFdb13aE8440A0C94Ef1A1af39e326` | same                                         | docs `reference/contracts/evm-v3`       |
| Ekubo CoreDataFetcher / QuoteDataFetcher                 | `0xF68F25CA…` / `0x5a3F0F1d…`                | same                                         | docs `reference/contracts/evm-v3`       |
| Uniswap v3 factory                                       | `0x33128a8fC17869897dcE68Ed026d694621f6FDfD` | `0x1F98431c8aD98523631AE4a59f267346ea31F984` | docs.uniswap.org v3 deployments         |
| Uniswap v3 SwapRouter (classic)                          | not listed by Uniswap for Base               | `0xE592427A0AEce92De3Edee1F18E0157C05861564` | docs.uniswap.org v3 deployments         |
| Uniswap v3 SwapRouter02                                  | `0x2626664c2603336E57B271c5C0b26F421741e481` | `0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45` | docs.uniswap.org v3 deployments         |
| Uniswap v4 PoolManager                                   | `0x498581fF718922c3f8e6A244956aF099B2652b2b` | `0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32` | docs.uniswap.org v4 deployments         |
| Uniswap v4 StateView                                     | `0xA3c0c9b65baD0b08107Aa264b0f3dB444b867A71` | `0x76Fd297e2D437cd7f76d50F01AfE6160f86e9990` | docs.uniswap.org v4 deployments         |
| WETH                                                     | `0x4200000000000000000000000000000000000006` | `0x82aF49447D8a07e3bd95BD0d56f35241523fBab1` | `symbol()`/`decimals()` read on-chain   |
| USDC (native)                                            | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | `0xaf88d065e77c8cC2239327C5EDb3A432268e5831` | `symbol()`/`decimals()` read on-chain   |
| USDT (Base) / USD₮0 (Arbitrum)                           | `0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2` | `0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9` | `symbol()`/`decimals()` read on-chain   |

The mainnet Ekubo `Router` (Solidity) has no listed L2 address in the docs (it is
deployment-specific), so the Ekubo leg is the Yul router only, which is also what the
mainnet headline uses. The address `0xE592427A…` on Base holds 4,221 bytes of unrelated
code and is not the Uniswap SwapRouter; Base's v3 leg therefore goes through SwapRouter02
(`exactInputSingle` without the `deadline` field, 228 bytes of calldata against 260). On
Arbitrum the classic SwapRouter is used for parity with mainnet and SwapRouter02 is
recorded as well (`ForkL2V3ArbitrumRouter02Test`).

### Endpoints and blocks

`https://base-rpc.publicnode.com` and `https://arbitrum-rpc.publicnode.com` served the chain
IDs, heads and code checks but refuse any historical state with `Archive requests require
a personal token` (Base already about 1,000 blocks behind head, Arbitrum at 100 blocks), so
the forks, the pool probes and the fee-oracle reads ran against
`https://base-mainnet.public.blastapi.io` and `https://arbitrum-one.public.blastapi.io`.
The L1-fee readings were cross-checked against `https://mainnet.base.org` and
`https://arb1.arbitrum.io/rpc` (identical to the wei, `l1-data-cost.json`).

| Chain        | Block       | Hash          | Timestamp                   | L2 base fee (wei) | Note                                                                         |
| ------------ | ----------- | ------------- | --------------------------- | ----------------- | ---------------------------------------------------------------------------- |
| Base         | `51439900`  | `0x54e5275d…` | 1789669147 (2026-09-17 UTC) | 5,000,000         | L1 origin block 25998943; Jovian active (`isJovian()` true)                  |
| Arbitrum One | `506178800` | `0x24768c22…` | 1789669181 (2026-09-17 UTC) | 20,074,000        | L1 block 25998959; `block.number` on the fork is that L1 number (Nitro rule) |

Because Foundry reports Arbitrum's `block.number` as the L1 block, the harness pins the
block by timestamp on both chains. Foundry 1.8.3 also selects its `optimism` network family
for chain 8453, and that family disables `CLZ` (EIP-7939) even at `evm_version = "osaka"`:
every Ekubo swap reverted with `NotActivated` until the Base run was given
`--network ethereum`. The opcode is live on the real chain (a Yul-router `quote` against the
live Base ETH/USDC pool executes through `eth_call`, `quote-live-base.mjs`), so the flag
restores the chain's actual EVM; it changes no opcode gas. Uniswap legs measure the same with
or without it.

### Pair choice: WETH/USDC, fresh Ekubo pool

The rule was USDC/USDT on a live Ekubo pool, else WETH/USDC with real Uniswap pools and a
freshly capitalized Ekubo pool. Neither chain has a live Ekubo pool that can absorb the
swap at the pinned blocks:

- Ekubo's own quoter (`prod-api-quoter.ekubo.org`) returns 107 USDC for 1000 USDT on Base
  (two USDC/USDT pools, both far off-price and near-empty) and `insufficient_liquidity`
  for every other pair tried on Base and for every pair on Arbitrum, including 10 USDC.
- The Ekubo API's `poolKeys` and `overview/tvl` for the two chains show total Core balances
  of about 0.002 ETH, 120 USDC and 120 USDT on Base and 0.002 ETH, 6,634 USDC (plus ARB)
  on Arbitrum. The one populated Base ETH/USDC pool (fee 0.05%, spacing 1000, liquidity
  1,498,307,833,298) would move tens of Uniswap ticks on a 100 USDC swap.

So the Ekubo leg on each chain is a pool created on the fork in the test's setup:
concentrated, no extension, the deepest live v3 WETH/USDC pool's fee tier and 100x its
tick spacing, initialized at the fine tick matching that pool's `sqrtPriceX96`, and
capitalized through a bare locker (`BareMintRouter`, never measured) with **exactly that
v3 pool's active liquidity** in a single position spanning ±60,000 fine ticks (about ±6%
in price). Both tokens are the real WETH and USDC contracts of the chain; Core already held
a nonzero balance of each before setup (2 wei of WETH and the USDC above), and holds the
minted amounts afterwards, so no measured swap pays a zero-to-nonzero balance write. The
Yul router calldata is generated by the SDK (`encode-l2-routes.mjs`) with the same config
word the test asserts against `createConcentratedPoolConfig`; the bytes the test sent are
written to `calldata/ekubo-yul-*.hex` and equal the SDK output (case-insensitive hex).

| Chain    | Leg           | Pool                                                                                  | Fee   | Spacing | Liquidity at block         | Tick at block |
| -------- | ------------- | ------------------------------------------------------------------------------------- | ----- | ------- | -------------------------- | ------------- |
| Base     | Ekubo (fresh) | id `keccak(WETH, USDC, 0x…c49ba5e353f7ce80001770)`, fee `55340232221128654 / 2^64`    | 0.3%  | 6000    | 37,026,042,371,903,555,946 | -19821136     |
| Base     | v3            | `0x6c561B446416E1A00E8E93E221854d6eA4171372` (deepest of 100/500/3000/10000)          | 0.3%  | 60      | 37,026,042,371,903,555,946 | -198222       |
| Base     | v4            | id `0x1d8c55f3…5a718f54`, hooks `address(0)` (deepest hookless of 100/500/3000/10000) | 0.3%  | 60      | 31,809,972,076,514,118     | -198217       |
| Arbitrum | Ekubo (fresh) | id `keccak(WETH, USDC, 0x…20c49ba5e353f7800003e8)`, fee `9223372036854775 / 2^64`     | 0.05% | 1000    | 3,696,581,650,313,474,097  | -19822971     |
| Arbitrum | v3            | `0xC6962004f452bE9203591991D15f6b388e09E8D0` (deepest of 100/500/3000/10000)          | 0.05% | 10      | 3,696,581,650,313,474,097  | -198240       |
| Arbitrum | v4            | id `0xfc7b3ad1…57028653`, hooks `address(0)` (deepest hookless of 100/500/3000/10000) | 0.05% | 10      | 52,128,164,974,525,471     | -198242       |

Other v3/v4 tiers probed at the pinned blocks (`getPool` + `liquidity()`, StateView
`getLiquidity`): Base v3 100/500/10000 = 7.68e16 / 1.48e18 / 6.15e16, v4 WETH/USDC
100/500/10000 = 0 / 3.72e14 / 0; Arbitrum v3 100/500/3000/10000 = 5.63e16 / 3.70e18 /
4.81e17 / 6.28e15, v4 WETH/USDC 100/3000/10000 = 5e9 / 1.64e11 / 0. The native
ETH/USDC v4 pools are deeper on both chains (8.14e17 at 0.3% on Base, 4.08e17 at 0.05% on
Arbitrum) but are a different pair (native ETH settlement) and were not used. The v4 pools
on both chains carry a nonzero protocol fee (`protocolFee` 2048500 on Base, 512125 on
Arbitrum) which the swap pays inside `PoolManager.swap`; that is production state, not a
harness choice.

### Sizes and tick movement

Swaps are USDC exact-input to WETH at 50, 100 and 1000 USDC. The measured swap's tick
movement is read from pool state before and after and cross-checked against the pool's
`Swap` event (v3 `slot0`/`Swap`, v4 StateView/`Swap`, Ekubo Core's 116-byte `log0` record).
At 100 USDC no leg moves more than one tick and no leg crosses an initialized tick, so 100
USDC is the size the docs page quotes; gas is identical at 50 USDC. At 1000 USDC the
shallow v4 WETH/USDC pools move 13 ticks on Base (no initialized tick crossed, gas
unchanged at 126,991) and 8 ticks on Arbitrum, crossing an initialized spacing-10 tick:
156,321 instead of 135,006. That row is kept in the snapshot as a reminder of why the
size was capped. Ekubo's fresh pool moves 0–1 fine ticks (1/100 of a Uniswap tick) at 100
USDC and 11 at 1000.

Outputs (wei of WETH for 100 USDC): Base Ekubo 40,448,346,569,108,551, v3
40,448,339,546,831,424, v4 40,400,300,715,083,769 (spread 0.12%, the v4 pool is 0.03% off
the v3 price); Arbitrum Ekubo 40,624,188,992,664,839, v3 40,624,162,908,750,166 (both
routers), v4 40,620,850,698,508,208 (spread 0.008%). The Ekubo and v3 legs agree to 7
significant figures because the fresh pool mirrors the v3 pool's price, fee and liquidity.

### Results

Execution gas is the isolated snapshot. Calldata bytes are the exact bytes of the measured
call (`calldata/*.hex`); "L2 calldata gas" is the 16/4 per byte intrinsic charge every L2
still levies inside its own gas (EIP-7623's floor never binds here). "L1 data" is what the
chain's own fee logic charges for posting the transaction, read at the pinned block (see
below), and its gas-equivalent is that wei amount divided by the block's L2 base fee.

| Chain    | Leg (100 USDC)                 | Execution | Calldata bytes (zero / nonzero) | L2 calldata gas | L1 data (wei)  | L1 data, L2-gas equivalent | L2 gas incl. 21,000 | Total gas-equivalent |
| -------- | ------------------------------ | --------- | ------------------------------- | --------------- | -------------- | -------------------------- | ------------------- | -------------------- |
| Base     | Ekubo Yul router               | 105,084   | 184 (99 / 85)                   | 1,756           | 1,655,831,768  | 331                        | 127,840             | 128,171              |
| Base     | v3 SwapRouter02                | 121,803   | 228 (177 / 51)                  | 1,524           | 1,596,015,122  | 319                        | 144,327             | 144,646              |
| Base     | v4 PoolManager, minimal locker | 126,959   | 292 (192 / 100)                 | 2,368           | 1,835,281,704  | 367                        | 150,327             | 150,694              |
| Arbitrum | Ekubo Yul router               | 113,121   | 184 (63 / 121)                  | 2,188           | 11,220,000,000 | 561                        | 136,309             | 136,870              |
| Arbitrum | v3 SwapRouter (classic)        | 130,896   | 260 (187 / 73)                  | 1,916           | 12,060,000,000 | 603                        | 153,812             | 154,415              |
| Arbitrum | v3 SwapRouter02                | 130,705   | 228 (159 / 69)                  | 1,740           | 11,400,000,000 | 570                        | 153,445             | 154,015              |
| Arbitrum | v4 PoolManager, minimal locker | 135,006   | 292 (174 / 118)                 | 2,584           | 12,880,000,000 | 644                        | 158,590             | 159,234              |

Base additionally tracks a Jovian "DA footprint" per transaction (block-space accounting,
not a fee): `max(100, (intercept + fastlzCoef × fastlzSize) / 1e6) × daFootprintGasScalar`,
with scalar 148 at the block: Ekubo 20,424, v3 19,684, v4 22,644 gas of DA footprint.

Ekubo against v3 / v4 at 100 USDC: execution 13.7% / 17.2% lower on Base and 13.6% / 16.2%
on Arbitrum (mainnet fork, 1000 USDT: 14.0% / 16.4%); whole transaction 11.4% / 14.9% on
Base and 11.4% / 14.0% on Arbitrum (mainnet: 11.7% / 14.2%). The L1 data component is
0.22–0.41% of every leg's total at these blocks, and Ekubo's is not the smallest on Base:
Fjord's FastLZ estimator prices the dense 184-byte route at 138.9 estimated compressed
bytes against 133.9 for the zero-padded 228-byte SwapRouter02 call. The same effect shows
in the L2 calldata gas column (1,756 against 1,524), because 16/4 pricing also rewards
zero bytes. On Arbitrum (Brotli) the Yul route is the cheapest to post, by 9–42 gas.

Per-leg execution gas differs from the mainnet figures because the pair and the token
contracts differ (WETH/USDC instead of USDT/USDC; Arbitrum's WETH and both chains' USDC
are proxies), and the Ekubo pool is fresh rather than live; the ratios between legs are
what carries over.

### Fee predeploys and formulas

Base (OP Stack; `GasPriceOracle` `0x420000000000000000000000000000000000000F` version
1.6.0, `isFjord`, `isIsthmus`, `isJovian` all true at the block; `L1Block`
`0x4200000000000000000000000000000000000015`). Values at block 51439900:

| Parameter              | Value       | Read from                        |
| ---------------------- | ----------- | -------------------------------- |
| `l1BaseFee`            | 118,337,311 | oracle / `L1Block.basefee()`     |
| `blobBaseFee`          | 7,219,357   | oracle / `L1Block.blobBaseFee()` |
| `baseFeeScalar`        | 2,269       | oracle / `L1Block`               |
| `blobBaseFeeScalar`    | 1,055,762   | oracle / `L1Block`               |
| `operatorFeeScalar`    | 0           | `L1Block`                        |
| `operatorFeeConstant`  | 0           | `L1Block`                        |
| `daFootprintGasScalar` | 148         | `L1Block`                        |

Fjord L1 cost (`specs/protocol/fjord/exec-engine.md`, implemented in `GasPriceOracle`):
`l1FeeScaled = baseFeeScalar × l1BaseFee × 16 + blobBaseFeeScalar × blobBaseFee`;
`estimatedSizeScaled = max(100 × 1e6, −42,585,600 + 836,500 × fastlzSize)` where
`fastlzSize` is the FastLZ-compressed length of the signed transaction (the oracle
compresses the unsigned RLP and adds 68 bytes for the signature); `l1Fee =
estimatedSizeScaled × l1FeeScaled / 1e12`. `l1-data-cost.mjs` builds the unsigned EIP-1559
transaction for each leg (chain id, nonce 100, priority fee 0.001 gwei, max fee 0.01 gwei,
gas limit 200,000, value 0, the leg's `to` and exact calldata; 228 / 273 / 338 bytes for
the three Base legs) and calls `getL1Fee(bytes)` and `getL1GasUsed(bytes)` on the oracle at
the pinned block; the estimated compressed size in the results is the oracle's own answer
divided back through the formula. The operator fee is zero at the block, so it adds
nothing.

Arbitrum One (Nitro; `ArbGasInfo` precompile `0x6C`, `NodeInterface` virtual contract
`0xC8`). Values at block 506178800: `getPricesInWei()` = (perL2Tx 4,317,615,680; per L1
calldata byte 30,840,112; per storage allocation 401,480,000,000; per ArbGas base
20,000,000; congestion 74,000; total 20,074,000), `getL1BaseFeeEstimate()` = 1,927,507
wei per L1 gas (so 30,840,112 = 16 × 1,927,507). The chain's poster charge
(`nitro/arbos/l1pricing/l1pricing.go`) is `pricePerUnit × units` with `units = 16 ×
brotli-compressed bytes of the signed transaction`; in estimation the units are padded by
256 and 1%. `l1-data-cost.mjs` calls `NodeInterface.gasEstimateL1Component(to, false,
data)` with `from` = the test contract at the pinned block; it returns the L1 component
already denominated in L2 gas (`gasEstimateForL1`, the table's gas-equivalent), the L2 base
fee it used (20,000,000, the block's minimum, against 20,074,000 in the header), and the L1
base fee estimate. The wei column is `gasEstimateForL1 × 20,000,000`. The precompiles are
not executable on the Foundry fork, so both chains' fee readings come from `eth_call`
against the archive endpoints, not from inside the tests.

### Reproducing the L2 numbers

```sh
# from a checkout with lib/ekubo (evm-contracts 1f5be49), lib/v4-core (46c6834, submodules),
# lib/forge-std (77041d2), lib/solady (65e87c7); foundry.toml and remappings.txt as in fork-l2/
forge test --fork-url https://base-mainnet.public.blastapi.io --fork-block-number 51439900 \
  --network ethereum --fork-retries 10 --fork-retry-backoff 2000 \
  --match-contract 'ForkL2EkuboBaseTest|ForkL2V3BaseTest|ForkL2V4BaseTest' -vv

forge test --fork-url https://arbitrum-one.public.blastapi.io --fork-block-number 506178800 \
  --fork-retries 10 --fork-retry-backoff 2000 \
  --match-contract 'ForkL2EkuboArbitrumTest|ForkL2V3ArbitrumTest|ForkL2V3ArbitrumRouter02Test|ForkL2V4ArbitrumTest' -vv

bun run encode-l2-routes.mjs      # regenerates the SDK routes (yul-router SDK checkout path inside)
bun run l1-data-cost.mjs > l1-data-cost.json   # fee-oracle readings (viem from the SDK's node_modules)
```

Foundry 1.8.3, `evm_version = "osaka"`, `via_ir`, `optimizer_runs = 1000000`, solc
auto-detected per file (0.8.26 Uniswap drivers, 0.8.33 Ekubo sources). `isolate = true` is
set per test.

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
