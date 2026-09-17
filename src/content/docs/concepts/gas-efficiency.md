---
description: Measured gas costs for Ekubo swaps against Uniswap v4 and v3, and what they mean for chain throughput
title: "Gas efficiency"
---

Ekubo is designed to make trading cheap: one singleton contract holds every pool,
and flash accounting settles only the net difference at the end of a transaction.
This page measures what that means in practice — what a swap costs, how many
swaps fit in a block, and what it would mean chain-wide — against Uniswap v4 and
Uniswap v3 on identical workloads. Every figure below runs production code
against production pools and routers on a mainnet fork wherever such a path
exists. The harnesses, raw snapshots, flamegraphs, and full methodology live in
`benchmarks/` in the docs repository.

## Bottom line

1000 USDT to USDC on mainnet (block 25991868), each leg through that
protocol's production swap path on live pools, warmed, moving the price by at
most one tick:

| Transaction                        | Ekubo, Yul router | Uniswap v3, SwapRouter | Uniswap v4, minimal locker |
| ---------------------------------- | ----------------- | ---------------------- | -------------------------- |
| Execution + 21,000 base + calldata | **133,750**       | 151,515                | 155,960                    |

Ekubo's transaction costs 11.7% less than v3's and 14.2% less than v4's. Output
matched the production quoter within 0.02% on the Ekubo leg, and all three legs
receive essentially the same output, so the gap is pure overhead, not price.

## Throughput per block

Mainnet's block gas limit is 60 million. Real swap flow is routes, not single
pools: every extra pool costs Ekubo about 24k in gas against v4's 34k and v3's
59k, so the per-transaction gap widens with route length. Dividing the limit by
measured route costs gives each protocol's ceiling on routes per block if a
block held nothing else (lab routes plus the 21,000 base; the fork row uses full
transaction gas):

| Routes per 60M block, if a block held nothing else | Ekubo             | Uniswap v4    | Uniswap v3 (net) |
| -------------------------------------------------- | ----------------- | ------------- | ---------------- |
| 1 pool, fork single hop, transaction gas           | 133,750 → **448** | 155,960 → 384 | 151,515 → 396    |
| 1 pool, lab route + 21,000                         | 115,904 → **517** | 128,360 → 467 | 115,078 → 521    |
| 2 pools, lab route + 21,000                        | 140,333 → **427** | 162,771 → 368 | 173,774 → 345    |
| 3 pools, lab route + 21,000                        | 164,774 → **364** | 197,182 → 304 | 232,470 → 258    |

At one pool the three protocols are within 12% of each other and v3's lab route
is marginally the cheapest; at three pools an Ekubo block holds 20% more routes
than a v4 block and 41% more than a v3 block.

## What this means for the chain

How much this matters chain-wide depends on the average number of pools a swap
touches and on how much block space swaps take. No published figure for pools
per swap was found for this page, so the blend below is a sensitivity, not an
estimate: a swap's transaction gas at an average of _p_ pools is the one-pool
lab route plus (_p_ − 1) times the marginal per extra pool, plus 21,000:

| Average pools per swap | Ekubo   | Uniswap v4 | Uniswap v3 (net) | Ekubo saving vs v4 / v3 |
| ---------------------- | ------- | ---------- | ---------------- | ----------------------- |
| 1.0                    | 115,904 | 128,360    | 115,078          | 9.7% / −0.7%            |
| 1.5                    | 128,119 | 145,566    | 144,426          | 12.0% / 11.3%           |
| 2.0                    | 140,333 | 162,771    | 173,774          | 13.8% / 19.2%           |

For the block-space share: over the 30 days ending September 17, 2026, mainnet
burned 1,255.7 ETH of base fees (ultrasound.money); transactions to known DEX
router contracts accounted for about 4.2% of that burn, a lower bound because
router-address attribution misses swaps routed through aggregators, MEV bundles,
and direct pool calls. Dune was unavailable to re-derive that share; ultrasound's
coarser "defi" category, which includes lending and everything else, was 19.4%
over the same window and brackets it from above.

Scenario math, with the assumptions stated: if a swap's share of the burn equals
its share of gas and the per-transaction saving applies to all of it, moving the
DEX-router slice to Ekubo would free, at the 4.2% lower bound, about 0.5–0.6% of
block gas chain-wide on the fork single-hop savings (11.7% against v3, 14.2%
against v4), 0.5% at an average of 1.5 pools per swap, and 0.6–0.8% at 2 pools;
if the whole "defi" slice behaved like swaps, 2.3–2.8% on single hops, 2.2–2.3%
at 1.5 pools and 2.7–3.7% at 2 pools. Induced demand would fill freed space.
Read these as an order of magnitude, not a forecast.

## Why it is cheaper

Three mechanisms, each measured, details in `benchmarks/`:

- **Cheaper pool core.** One packed storage word and Q64 fixed-point math cost
  about 20k gas per swap, against 29k for v4's multi-slot state and 37k for
  v3's slot0, fee-growth, and tick bookkeeping.
- **Net settlement.** Ekubo and v4 settle once per transaction (2 token
  transfers for a route of any length); v3 pays 2 transfers per pool. So each
  extra pool costs about 24k on Ekubo, 34k on v4, 59k on v3.
- **Compact calldata where it counts.** The production Yul router packs a route
  into 184 bytes; Uniswap's Universal Router needs 548 bytes for a single V3
  swap before any Permit2 funding command. (Ekubo's Solidity router is even
  shorter at 132 bytes; its cost is execution-side instead.)

## Measured honestly

Providing liquidity is measured at the tier providers actually touch:
production position managers on the same fork pools. Minting a new ~10,000
USDC/USDT position costs 244,513 on Ekubo against 297,390 on v4 (17.8% less)
and 381,653 on v3 (35.9% less). Bare direct-to-core calls are a different,
unsendable tier and live in `benchmarks/`; one-time costs (pool creation, tick
initialization, first-swap writes) are excluded by design everywhere on this
page. Native ETH swaps cost 72,580 on Ekubo against 88,864 on v4; v3 pools hold
WETH, so its users pay a 27,938 wrapping deposit first.

Scope: EVM only, concentrated pools, no hooks or extensions on any side — any
v4 hook or Ekubo extension changes every number here.

## How it was measured

- Production contracts, routers, and live pools on a mainnet fork pinned at
  block 25991868; lab scaling on minimal single-lock routers with one shared
  ERC20 token contract, economically matched liquidity, no tick crossings.
- Warmed steady state throughout: one identical unmeasured call precedes every
  measurement. Both swap directions covered.
- Minimal routers on all sides, which favors Uniswap: production routers cost
  more than the lab numbers.
- Full harness sources, raw snapshots, reference calldata, flamegraphs, pool
  identifiers, and reproduction commands: `benchmarks/` in the docs repository.
