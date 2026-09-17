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
touches and on how much block space swaps take.

**Pools per swap, measured.** Over 200 consecutive mainnet blocks (25997689 to
25997888, September 17, 2026, 14:04 to 14:44 UTC), every successful transaction
that emitted at least one pool-level swap event (Uniswap v2 and its forks, v3,
v4, Curve) was counted by the number of such events it contains:

| Pools touched in the transaction | Share of swap transactions |
| -------------------------------- | -------------------------- |
| 1                                | 71.5%                      |
| 2                                | 15.6%                      |
| 3                                | 6.2%                       |
| 4 or more                        | 6.6%                       |

That is 5,341 swap transactions at an average of **1.66 pools per swap**. The
subset sent directly to the Uniswap and 1inch routers (470 transactions, hop
counts decoded from calldata and matched against their events in every case)
averages only 1.11 pools, so most multi-pool weight comes from aggregators, MEV
and other contracts rather than from retail router calls. Failed transactions
emit no logs and are excluded by construction. Method, tables and script are in
`benchmarks/`.

A swap's transaction gas at an average of _p_ pools is the one-pool lab route
plus (_p_ − 1) times the marginal per extra pool, plus 21,000. The measured
average is the headline blend; the router-only average and the round values are
kept as context:

| Average pools per swap | Ekubo       | Uniswap v4 | Uniswap v3 (net) | Ekubo saving vs v4 / v3 |
| ---------------------- | ----------- | ---------- | ---------------- | ----------------------- |
| **1.66 (measured)**    | **131,958** | 150,974    | 153,652          | **12.6% / 14.1%**       |
| 1.11 (routers only)    | 118,504     | 132,022    | 121,324          | 10.2% / 2.3%            |
| 1.0                    | 115,904     | 128,360    | 115,078          | 9.7% / −0.7%            |
| 1.5                    | 128,119     | 145,566    | 144,426          | 12.0% / 11.3%           |
| 2.0                    | 140,333     | 162,771    | 173,774          | 13.8% / 19.2%           |

For the block-space share: over the 30 days ending September 17, 2026, mainnet
burned 1,255.7 ETH of base fees (ultrasound.money); transactions to known DEX
router contracts accounted for about 4.2% of that burn, a lower bound because
router-address attribution misses swaps routed through aggregators, MEV bundles,
and direct pool calls. Ultrasound's coarser "defi" category, which includes
lending and everything else, was 19.4% over the same window and brackets it from
above. In the 200-block window above, the transactions that emitted a pool swap
event used 30.3% of all gas, which confirms the router figure is a floor. A
third, higher share of 70% is included below because it was stipulated for this
page as an "all AMM trading" upside case; it is an assumption handed to the
analysis, not a measurement.

Scenario math, with the assumptions stated: if a swap's share of the burn equals
its share of gas and the per-transaction saving applies to all of it, moving
that slice to Ekubo would free the share times the saving. Each cell is the
range spanned by the saving against v3 and the saving against v4 (the two
savings are in the column header, v3 first):

| Block-space share given to swaps                  | Fork single hop (v3 11.7%, v4 14.2%) | Measured 1.66 pools (v3 14.1%, v4 12.6%) | 2.0 pools (v3 19.2%, v4 13.8%) |
| ------------------------------------------------- | ------------------------------------ | ---------------------------------------- | ------------------------------ |
| 4.2%, measured DEX-router burn, lower bound       | 0.5–0.6%                             | 0.5–0.6%                                 | 0.6–0.8%                       |
| 19.4%, "defi" category bracket                    | 2.3–2.8%                             | 2.4–2.7%                                 | 2.7–3.7%                       |
| 70%, stipulated AMM-trading upside (not measured) | 8.2–10.0%                            | 8.8–9.9%                                 | 9.7–13.5%                      |

At the measured blend and the measured lower bound, Ekubo frees about half a
percent of block gas chain-wide; at the stipulated 70% share it would be
roughly nine percent. Induced demand would fill freed space. Read these as an
order of magnitude, not a forecast.

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
- Pools per swap: 200 mainnet blocks read through a public JSON-RPC endpoint
  (block receipts for the event count, full blocks for the router calldata
  cross-check). Uniswap v2 and all its forks share one event signature and are
  counted as one family.
- Full harness sources, raw snapshots, reference calldata, flamegraphs, pool
  identifiers, and reproduction commands: `benchmarks/` in the docs repository.
