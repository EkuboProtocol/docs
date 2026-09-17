---
description: Measured gas costs for Ekubo swaps and mints against Uniswap v4 and v3, with like-for-like benchmarks, scaling analysis, mainnet-fork validation through the production routers and position managers, and chain-capacity implications
title: "Gas efficiency"
---

Ekubo is designed to make trading cheap: one singleton contract holds every pool,
[flash accounting](/concepts/key-concepts/) settles only net differences, and pool
state packs into a single storage word. This page backs that design claim with
measured numbers — full methodology, harness sources, and flamegraphs included —
comparing Ekubo on EVM against Uniswap v4 and Uniswap v3 on identical workloads.

Two bases appear on this page and are never mixed inside one sentence:

- **Execution gas** is what the measured call consumed, net of end-of-transaction
  refunds. It excludes the 21,000 transaction base cost and calldata. Every table
  is on this basis unless its heading says otherwise.
- **Transaction gas** adds 21,000 plus the exact calldata cost of a reference
  calldata file in `benchmarks/fork/` (4 gas per zero byte, 16 per nonzero byte).
  The post-Pectra calldata floor (EIP-7623) was checked and does not bind on any
  transaction here.

Two conditions also recur. **Steady state** means the pool has already been
swapped through: one identical, unmeasured swap precedes the measured one, so
the figure is what an established pool charges. **First swap in a fresh pool**
means no swap has touched the pool since it was capitalized in setup.

Lab figures use a 0.3% concentrated-liquidity pool with one position covering the
whole tick space and no extension or hook, exact-input swaps of one 18-decimal
token, and the same ERC20 token contract in every harness.

## Single swaps

Steady state, both directions, execution gas. Each column is that protocol's
cheapest path: Ekubo's production Solidity `Router` (its single-swap entry), a
true-minimal v4 locker (unlock, swap, settle, take), and for v3 a direct
`pool.swap` with the test contract paying the callback.

| Swap                              | Ekubo      | Uniswap v4 | Uniswap v3                            |
| --------------------------------- | ---------- | ---------- | ------------------------------------- |
| ERC20 to ERC20                    | **87,416** | 103,533    | 87,641                                |
| ERC20 to ERC20, reverse direction | **86,334** | 103,358    | 87,040                                |
| Native ETH to ERC20               | **72,580** | 88,864     | n/a (v3 pools hold WETH)              |
| ERC20 to ERC20, bare locker       | **87,077** | 103,533    | n/a (an EOA cannot pay a v3 callback) |

Ekubo's ERC20 swap uses 15.6% less execution gas than v4. On transaction gas,
adding 21,000 plus each entry point's calldata (Ekubo Router 132 bytes, 1,200
gas; v4 minimal locker 292 bytes, 2,572 gas), it is 109,616 against 127,105,
or 13.8% less. The bare-locker row is the like-for-like comparison of two
true-minimal lockers with the same four steps: 87,077 against 103,533, 15.9%
less. Ekubo's production Router costs only 339 gas more than its bare locker.

The v3 direct call is a floor, not a sendable path: an externally owned account
cannot be a v3 callback payer, so the cheapest transaction a v3 user can send is
the one-pool route in the next section, 94,078 gas. Against that, Ekubo's
single swap is 7.1% cheaper; against the unreachable floor, the two are within
0.3% of each other.

**First swap in a fresh pool.** Without the warm-up swap, Ekubo measures 87,384
(32 gas below steady state), v4 120,633 and v3 104,741: exactly 17,100 more on
both Uniswap versions, one zero-to-nonzero write of the fee-growth accumulator
(20,000 gas instead of 2,900). State-diff recording confirms one fresh slot on
v3 and v4 and none on Ekubo, whose `initializePool` writes both fee accumulator
slots up front (see [Creating a pool](#creating-a-pool)). Ekubo's native-input
first swap measures 72,560 against 72,580 in steady state. Reverse-direction
first swaps were not measured.

**v3's oracle write.** A v3 swap that changes the tick also writes an oracle
observation, at most once per block. The same tick-changing swap costs 89,836
in the block of a previous swap (write skipped) and 93,712 in the next block
(observation written): 3,876 gas for the write, paid by the first tick-moving
swap of every block. Neither Ekubo nor v4 writes an oracle inside the swap path
(Ekubo's oracle is an extension, v4's would be a hook).

**Native input.** Ekubo takes ETH directly and spends 18.3% less execution gas
than v4 doing the same; each path makes exactly two value-bearing calls (user to
router, router to Core or PoolManager), and Ekubo's bare locker measures 72,164.
v3 pools hold WETH, so a v3 user first wraps: one `deposit` costs 27,938
execution gas in steady state (the account already holds WETH; a first-ever wrap
pays a zero-to-nonzero balance write on top). Counting the wrap, a v3 ETH-input
trade is at least 115,579 execution gas across two calls, so Ekubo spends 37%
less, before the 21,000 base and calldata of a separate wrapping transaction.

## How the gap scales with route length

Routing through one, two, and three pools in a single transaction, steady state,
each protocol using a minimal router of the same shape (Ekubo's production
`Router` multihop entry, a single-lock v4 router, and a v3 router with the
production SwapRouter's token flow). Execution gas, net of refunds; the v3 series
is the only one that earns refunds, so its gross figure and refund are shown:

| Route length                     | Ekubo      | Uniswap v4 | Uniswap v3, net (gross, refund) |
| -------------------------------- | ---------- | ---------- | ------------------------------- |
| 1 pool                           | 94,904     | 107,360    | 94,078 (94,078, 0)              |
| 2 pools                          | 119,333    | 141,771    | 152,774 (172,674, 19,900)       |
| 3 pools                          | 143,774    | 176,182    | 211,470 (251,270, 39,800)       |
| **Marginal cost per extra pool** | **24,429** | **34,411** | **58,696** (78,596 gross)       |

Ekubo's two marginals are 24,429 and 24,441; v4's and v3's repeat exactly,
because each added hop hits an identically shaped pool with its own token
contracts. At one pool the three are close: Ekubo's multihop entry is 11.6%
below v4 and 0.9% above v3's route, which is nothing more than two transfers and
one pool call. At three pools Ekubo is 18.4% below v4 and 32.0% below v3 net
(42.8% below v3 gross). A real route's first hop pays the first-swap surcharge
from the previous section on v4 and v3 if its pool is fresh; the marginals here
are the right measure for the hops after it.

The v3 refund is 19,900 per intermediate hop: the router's balance of each
intermediate token goes from zero to nonzero and back to zero inside the
transaction, and EIP-3529 refunds the clearing. The refund is capped at one
fifth of gas used, which does not bind at these sizes, so the net figure is what
a user pays.

Token transfers tell part of the story. Ekubo and v4 both settle net inside one
lock, so a route of any length moves exactly two tokens:

| Transfers per route | Ekubo     | Uniswap v4 | Uniswap v3 |
| ------------------- | --------- | ---------- | ---------- |
| 1 / 2 / 3 pools     | 2 / 2 / 2 | 2 / 2 / 2  | 2 / 4 / 6  |

v3 pays two transfers per pool (callback payment plus output) because every pool
is a separate contract that must be paid individually. But transfers alone do not
explain the v4 gap — v4 nets transfers exactly like Ekubo. The rest of the
difference is inside the pool core.

## Where the savings come from

Frame-level attribution of the steady-state single swap, from Foundry
flamegraphs. Each capture is one call on a pool that has already been swapped
through, so the router call frame equals the corresponding table entry; the
outer root frame also counts the harness's own call into the router. Frame
widths are proportional to gas.

![Flamegraph of an Ekubo single-hop swap](/gas/flamegraph-ekubo-single.svg)
_Flamegraph: Ekubo single swap through the Router, steady state. Router call
frame 87,416 gas; root frame 99,218 gas including the harness call._

![Flamegraph of a Uniswap v4 single-hop swap](/gas/flamegraph-v4-single.svg)
_Flamegraph: Uniswap v4 single swap through the minimal locker, steady state.
Locker call frame 103,533 gas; root frame 115,439 gas including the harness call._

![Flamegraph of a Uniswap v3 single-hop swap](/gas/flamegraph-v3-single.svg)
_Flamegraph: Uniswap v3 one-pool route through the SwapRouter-shaped minimal
router, steady state (the cheapest path a user can send). Router call frame
94,078 gas; root frame 108,327 gas including the harness call._

Reading the call frames off the three graphs:

| Component                                                         | Ekubo (87,416)              | Uniswap v4 (103,533)               | Uniswap v3 route (94,078)     |
| ----------------------------------------------------------------- | --------------------------- | ---------------------------------- | ----------------------------- |
| Pool math and state (the core swap frame, transfers excluded)     | Core swap: **20,363** (23%) | PoolManager swap: **28,884** (28%) | Pool internals: ~36,800 (39%) |
| Token settlement (two ERC20 transfers plus the calls around them) | 37,680 (43%)                | 38,024 (37%)                       | ~29,600 (31%)                 |
| Entry point, lock or unlock, and callback plumbing (remainder)    | 29,373 (34%)                | 36,625 (35%)                       | 27,648 (29%)                  |

The v3 split is approximate because its pool frame (66,430) contains the
callback payment and the output transfer; those and the balance checks are
moved into the settlement row. Three observations:

- **The pool core is where Ekubo wins.** One packed storage word and Q64
  fixed-point math cost about 20k per swap, against 29k for v4's multi-slot state
  with protocol-fee and donation bookkeeping, and about 37k for v3's slot0,
  fee-growth, and tick bookkeeping. On a first swap in a fresh pool the two
  Uniswap cores each cost 17,100 more.
- **Settlement is a wash between Ekubo and v4.** Flash-accounting settlement
  costs about 38k on both (two transfers of about 12.5k each plus the payment
  and withdrawal accounting); v3 spends less on settlement per pool because it
  moves tokens directly, then spends it back twice per extra pool.
- **Plumbing is cheap on Ekubo.** The Router's ABI round-trip and lock cost about
  29k, under v4's unlock and callback plumbing at about 37k. The core win
  compounds across multi-pool routes, where Ekubo adds one cheap pool call per
  hop instead of another full settle-and-callback cycle.

## Providing liquidity

Minting is measured at two tiers. The **user-facing tier** is what a liquidity
provider actually sends: a mint through each protocol's production position
manager, which issues the NFT, pulls the tokens, and calls the core. The **bare
tier** is a direct core call from a lab harness with no NFT and no manager, a
path no externally owned account can send on any of the three protocols.

**User-facing tier, mainnet fork.** A new full-range position of about 10,000
USDC and 10,000 USDT on the same live USDC/USDT pools as the
[fork swaps](#mainnet-fork-validation), pinned at block 25991868, through the
deployed Ekubo Positions contract, the deployed Uniswap v4 PositionManager
(`MINT_POSITION` plus `SETTLE_PAIR`, tokens pulled through Permit2), and the
deployed Uniswap v3 NonfungiblePositionManager. Execution gas of the measured
mint. One identical, unmeasured mint of a separate NFT precedes it, so on every
leg the boundary ticks are initialized and the minter already owns an NFT; the
second row instead mints a range whose two boundary ticks no position uses,
after the same warm-up, so it includes tick initialization:

| Mint on mainnet fork                             | Ekubo Positions | Uniswap v4 PositionManager | Uniswap v3 NonfungiblePositionManager |
| ------------------------------------------------ | --------------- | -------------------------- | ------------------------------------- |
| New position, boundary ticks already initialized | **244,513**     | 297,390                    | 381,653                               |
| New position, both boundary ticks fresh          | **369,791**     | 376,984                    | 522,450                               |

At the tier users touch, Ekubo's mint uses 17.8% less execution gas than v4's
and 35.9% less than v3's. Fresh boundary ticks narrow the gap: initializing two
ticks costs 125,278 on Ekubo, 79,594 on v4 and 140,797 on v3, so with both
ticks fresh Ekubo is 1.9% below v4 and 29.2% below v3. Every leg's mint is
proven by state: the NFT is owned by the minter, the position's liquidity is
recorded (9,996,041,392 on Ekubo, 9,996,510,484 on v4, 9,996,546,576 on v3),
the pool's active liquidity grows by that amount, and the minter's USDC and USDT
balances fall by the amounts pulled (about 9,992–9,993 USDC and exactly 10,000
USDT on each). The fork figures are not comparable to the lab table below: they
run against the real USDC proxy and USDT contracts instead of the shared mock
token, and pull tokens through each manager's own path.

**Bare tier, lab.** An economically matched full-range position (1M tokens a
side) as a new position whose boundary ticks are already initialized, direct to
the core on each protocol. Execution gas; the v3 rows earn a 2,800 refund, so
gross figures are shown:

| Mint path, lab                                 | Ekubo   | Uniswap v4 | Uniswap v3, net (gross, refund) |
| ---------------------------------------------- | ------- | ---------- | ------------------------------- |
| New position, bare / direct to core            | 179,020 | 162,188    | **138,380** (141,180, 2,800)    |
| Top-up of an existing position, direct         | —       | —          | 121,496 (124,296, 2,800)        |
| New position through the Positions NFT (Ekubo) | 213,104 | —          | —                               |

The bare tier is the one place Ekubo is not cheapest: its bare mint costs 10.4%
more than v4's and 29.4% more than a new v3 position (26.8% more against v3
gross). The v3 top-up row is cheaper still because the position's slots are
already nonzero; it is not a new position and has no counterpart above. In the
lab, Ekubo's Positions NFT adds 34,084 (19%) over the bare path for the token
mint, metadata, and protocol-fee accounting. The ordering reverses between the
two tiers: bare, v3 is cheapest and Ekubo dearest; through the production
managers, Ekubo is cheapest and v3 dearest. Core is optimized for the operation
that happens orders of magnitude more often, and the Positions contract is thin
enough that the whole user path is the cheapest of the three.

## Creating a pool

Initializing a pool once, execution gas:

| Operation                   | Ekubo  | Uniswap v4 | Uniswap v3                                                        |
| --------------------------- | ------ | ---------- | ----------------------------------------------------------------- |
| Initialize an existing pool | 92,935 | 51,812     | 70,328 (plus `createPool`: 4,558,970 to deploy the pool contract) |

Ekubo's `initializePool` is 41,123 gas more than v4's `initialize` because it
writes both fee-per-liquidity accumulator slots from zero at creation (two
20,000-gas writes); that is exactly what spares every Ekubo pool the 17,100-gas
first-swap surcharge that v4 and v3 pay. v3 pools are separate contracts, so
creating one costs 4.63 million gas in total.

## Mainnet-fork validation

Lab harnesses control everything, so the same comparison was re-run where it
matters: one pair, production code, real liquidity. All three legs swap USDT to
USDC on a mainnet fork pinned at block 25991868, steady state (one identical
unmeasured swap first), at two sizes. Execution gas and the USDC received:

| Swap on mainnet fork | Ekubo                    | Uniswap v4           | Uniswap v3           |
| -------------------- | ------------------------ | -------------------- | -------------------- |
| 1000 USDT to USDC    | **110,622** (999.176773) | 132,388 (999.169404) | 128,611 (999.209400) |
| 100 USDT to USDC     | **110,591** (99.920076)  | 132,424 (99.917651)  | 128,611 (99.920949)  |

That is 14.0% less execution gas than v3 and 16.4% less than v4 at 1000 USDT
(14.0% and 16.5% at 100 USDT); the size barely matters because each swap moves
the price by 0–1 ticks. The pools, identified on-chain at the pinned block:

- **Ekubo:** the live USDC/USDT concentrated pool with no extension (core only),
  config word `0x…53e2d6238da480000032`: fee `0x53e2d6238da4` / 2^64
  (0.0005%), tick spacing 50 (Ekubo ticks are 100x finer than Uniswap's), pool
  id `0x6fde3244f6fa747ae318aba6e982a4281febad4d22e3b134aa299a83a951895d`,
  swapped through the deployed production Yul router with SDK-generated
  calldata. The output matched the production quoter within 0.02%.
- **Uniswap v3:** pool `0x3416cF6C708Da44DB2624D63ea0AAef7113527C6`, fee 0.01%
  (fee-100), tick spacing 1, chosen as the deepest of the fee-100, 500 and 3000
  USDC/USDT pools at the block; through the deployed SwapRouter
  `exactInputSingle`.
- **Uniswap v4:** pool id
  `0xe018f09af38956affdfeab72c2cefbcd4e6fee44d09df7525ec9dba3e51356a5`, fee
  0.01%, tick spacing 1, `hooks = address(0)`, confirmed initialized under that
  key (nonzero price), so the pool has no hook; the deepest of the same three
  fee tiers. Through the deployed PoolManager with a minimal locker; the
  Universal Router would cost more.

In every leg the recipient is the test contract, which already holds USDT (via
`deal`), holds USDC after the warm-up swap (asserted), and has granted the router
under test a maximum allowance (asserted), so no measured call pays a
zero-to-nonzero balance or allowance write. Fee tiers differ across venues,
which does not change the code path. USDT returns no data from `approve` and
`transferFrom`, so the v4 locker settles with low-level calls, as production
routers do.

The same three pools carry the user-facing mint comparison in
[Providing liquidity](#providing-liquidity), through the deployed Ekubo
Positions contract (`0x02D9876A21AF7545f8632C3af76eC90b5ad4b66D`), the v4
PositionManager (`0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e`, the canonical
mainnet deployment listed by Uniswap, verified on the fork by its `poolManager`
and `permit2` wiring) and the v3 NonfungiblePositionManager
(`0xC36442b4a4522E871399CD717aBDD847Ab11FE88`).

## Calldata: the production routers

Execution gas excludes the transaction's calldata, which is where router design
shows up a second time. Reference calldata for the same 1000-USDT swap shape,
byte counts verified by decoding each file:

| Router call                              | Calldata  | Calldata gas |
| ---------------------------------------- | --------- | ------------ |
| Ekubo Yul router (production route)      | 184 bytes | 2,128        |
| Ekubo Solidity `Router`, single swap     | 132 bytes | 1,200        |
| Uniswap SwapRouter `exactInputSingle`    | 260 bytes | 1,904        |
| Uniswap Universal Router, single V3 swap | 548 bytes | 3,200        |
| Minimal v4 locker (fork harness)         | 292 bytes | 2,572        |

Two things stand out. First, the Yul router's packed route (184 bytes) is
longer than the Solidity Router's ABI call (132 bytes): its optimization is
execution-side (no ABI round-trip, one lock for the whole route), not
calldata-side, and the fork measurement captures exactly that. Second, the
Universal Router is by far the heaviest: command-dispatch generality costs over
500 bytes before any Permit2 funding command, which realistic flows prepend on
top (first-time Permit2 approvals are excluded here, as are the one-time token
approvals in every harness).

Calldata is second-order next to execution, a 1–2k spread against 20–60k
execution gaps, but it moves the fork totals the same way. Transaction gas for
the 1000-USDT fork swaps, execution plus 21,000 plus the calldata above:

| Transaction on mainnet fork | Ekubo, Yul router                      | Uniswap v3, SwapRouter             | Uniswap v4, minimal locker         |
| --------------------------- | -------------------------------------- | ---------------------------------- | ---------------------------------- |
| 1000 USDT to USDC           | **133,750** (110,622 + 21,000 + 2,128) | 151,515 (128,611 + 21,000 + 1,904) | 155,960 (132,388 + 21,000 + 2,572) |

Ekubo's transaction costs 11.7% less than v3's and 14.2% less than v4's. The
100-USDT transactions differ from these by under 100 gas. A Universal Router
leg would widen both Uniswap gaps on calldata and execution alike. The EIP-7623
floor for these transactions is about 24,000–29,000 gas in total (21,000 plus
10 gas per calldata token), far below their regular cost, so it never binds.

## What this means for chain capacity

Mainnet's block gas limit is 60 million (59,999,943 at the fork block 25991868
and unchanged at block 25994835 on September 17, 2026). Dividing the limit by
the transaction gas of the fork swaps gives each protocol's ceiling on
single-hop swaps per block if a block held nothing else:

| Basis: 1000 USDT fork swap, transaction gas | Ekubo   | Uniswap v3 | Uniswap v4 |
| ------------------------------------------- | ------- | ---------- | ---------- |
| Gas per swap                                | 133,750 | 151,515    | 155,960    |
| Swaps per 60M block                         | **448** | 396        | 384        |

The chain-wide effect depends on how much block space swaps take. Over the 30
days ending September 17, 2026, mainnet burned 1,255.7 ETH of base fees
(ultrasound.money); transactions to known DEX router contracts accounted for
about 4.2% of that burn, a lower bound because router-address attribution misses
swaps routed through aggregators, MEV bundles, and direct pool calls. Dune was
unavailable to re-derive that share; ultrasound's coarser "defi" category, which
includes lending and everything else, was 19.4% over the same window and
brackets it from above.

Scenario math, with the assumptions stated: if a swap's share of the burn equals
its share of gas, every such swap is a single hop like the fork swaps, and the
per-transaction saving above (11.7% against v3, 14.2% against v4) applies to
all of them, moving the DEX-router slice to Ekubo would free about 0.5–0.6% of
block gas chain-wide at the 4.2% lower bound, and 2.3–2.8% if the whole "defi"
slice behaved like swaps. Multi-pool routes save more per transaction (18.4%
against v4 and 32.0% against v3 at three pools), and induced demand would fill
freed space. Read these as an order of magnitude, not a forecast.

## Methodology and limitations

- **Toolchains.** Each protocol compiles under its own production settings
  (Ekubo: solc 0.8.33, 9,999,999 optimizer runs, via IR, Osaka; v4: v4-core's
  own settings; v3: canonical mainnet bytecode), all on Foundry 1.8.3. Every
  test runs on a fresh chain; measured calls run under Foundry's `isolate`
  setting, which gives each top-level call its own EVM context so that
  end-of-call refunds are applied, and `snapshotGasLastCall` reports that call's
  execution gas. It excludes the 21,000 base and calldata: the non-isolated
  flamegraph frame for the same call matches the isolated snapshot to the gas
  unit. Transaction gas on this page is computed, never measured.
- **Headline basis.** Single swaps and routes are steady state, with a first-swap
  note where the difference matters (Ekubo about the same, v4 and v3 +17,100).
  `vm.cool` was checked while building the harnesses and changed no figure; no
  committed test uses it. Switching the v3 and v4 harnesses from Cancun to Osaka
  changes none of their swap figures.
- **Refunds.** Snapshots are net of EIP-3529 refunds. The v3 harness also records
  the gross figure and the refund granted next to every snapshot; every Ekubo
  and v4 measurement has zero refund.
- **Like for like.** One identical token artifact (solmate `MockERC20`, deployed
  from the same bytecode) runs in every lab harness. Every recipient already
  holds the output token, and every router delivers output to the calling user,
  so no measured call pays a zero-to-nonzero balance write the others avoid.
  Liquidity is economically matched (1M tokens a side; v3 mints the equivalent
  liquidity for the same amounts), pools are initialized strictly inside a tick,
  and no swap crosses an initialized tick.
- **Routers.** Deliberately minimal on all sides, which favors Uniswap:
  production routers (Universal Router, SwapRouter, and Ekubo's own frontend
  path) all cost more than the lab numbers. Ekubo is additionally measured
  through its production Solidity `Router`; the v3 direct pool call is a floor
  an externally owned account cannot send. Mints are the exception: the
  user-facing tier goes through each protocol's deployed production position
  manager on the fork, with the one-time token approvals (and, for v4, the
  Permit2 allowance) granted in setup and not measured.
- **Scope.** No-crossing swaps on hookless, extensionless pools: any v4 hook or
  Ekubo extension changes every number on this page, while pool configuration
  (fee, tick spacing) barely moves them. Both swap directions are covered.
- **Fork.** Pinned block 25991868, production contracts and live pools
  identified by on-chain probing, warmed as in the lab, negligible tick
  movement. Fee tiers differ across venues. Fork mints use each pool's widest
  spacing-aligned range (tick spacing 1 on both Uniswap pools, 50 on Ekubo), so
  the three positions are not identical in liquidity, only in size; mints do
  not move price.

The complete harnesses, raw snapshots, reference calldata, flamegraphs, and
reproduction commands live in `benchmarks/` alongside these docs.
