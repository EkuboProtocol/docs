---
description: Measured gas costs for Ekubo swaps against Uniswap v4 and v3, and what they mean for chain throughput
title: "Gas efficiency"
---

Ekubo is designed to make trading cheap: one singleton contract holds every pool,
and flash accounting settles only the net difference at the end of a transaction.
This page measures what that means in practice — what a swap costs, how many
swaps fit in a block, and what it would mean chain-wide — against Uniswap v4 and
Uniswap v3. Every figure runs the deployed production contracts of all three
protocols on a fork of the latest mainnet block, with fresh plain ERC20 tokens so
token quirks do not blur the comparison. Harnesses, raw snapshots, exact calldata
and the full method live in `benchmarks/` in the docs repository.

## Bottom line

One swap of 1 token through a single 0.3% pool of a fresh ERC20 pair, warmed,
moving the price by at most one tick, at block 25999935 (September 17, 2026).
Transaction gas is execution plus the 21,000 base plus the measured calldata:

| Transaction, 1 pool                                                       | Ekubo       | Uniswap v4 | Uniswap v3 |
| ------------------------------------------------------------------------- | ----------- | ---------- | ---------- |
| Production router (Yul router; Universal Router with Permit2; SwapRouter) | **110,875** | 144,390    | 123,587    |
| Minimal single-lock router on every side (favors Uniswap)                 | **112,997** | 131,284    | 117,006    |
| Native ETH in (Yul router; minimal locker; SwapRouter wrapping in flight) | **96,496**  | 115,892    | 126,792    |

Through the production routers, Ekubo's transaction costs 23.2% less than v4's
and 10.3% less than v3's. With every router stripped to the same minimal
lock-swap-settle shape the gap is 13.9% to v4 and 3.4% to v3: at one pool v3's
pool is nearly as cheap, and the difference is in the router and beyond the first
pool. With native ETH in, Ekubo is 16.7% below v4 and 23.9% below v3, which must
wrap. All legs receive the same output within 0.005%, so the gap is overhead, not
price. At the expensive end, 1000 USDT to USDC on the live mainnet pools (proxy
tokens, blocklists) costs 133,750 on Ekubo against 155,960 on v4 and 151,515 on
v3, 14.2% and 11.7% less: costly tokens compress the gap but do not close it.

## Throughput per block

Mainnet's block gas limit is 60 million. Real swap flow is routes, not single
pools: every extra pool costs Ekubo about 24k of transaction gas against v4's 36k
and v3's 59k, so the gap widens with route length. Dividing the limit by measured
route costs gives each protocol's ceiling on routes per block if a block held
nothing else (minimal routers on every side, which favors Uniswap):

| Routes per 60M block, if a block held nothing else | Ekubo             | Uniswap v4    | Uniswap v3    |
| -------------------------------------------------- | ----------------- | ------------- | ------------- |
| 1 pool, production routers                         | 110,875 → **541** | 144,390 → 415 | 123,587 → 485 |
| 1 pool, minimal routers                            | 112,997 → **530** | 131,284 → 457 | 117,006 → 512 |
| 2 pools, minimal routers                           | 137,091 → **437** | 167,027 → 359 | 176,438 → 340 |
| 3 pools, minimal routers                           | 161,184 → **372** | 202,770 → 295 | 235,870 → 254 |

At three pools an Ekubo block holds 26% more routes than a v4 block and 46% more
than a v3 block.

## What this means for the chain

**Pools per swap, measured over a month.** Every 10th mainnet block from
August 18, 2026, 18:36 UTC to September 17, 2026, 21:08 UTC (21,600 blocks, 25783810 to 25999800) was
read through public JSON-RPC, and every successful transaction that emitted a
pool-level swap event was counted by the number of such events. The event set
covers Uniswap v2 and its forks, v3, v4, PancakeSwap v3, Curve (all generations),
Balancer v2 and v3, Maverick v1 and v2, Fluid, DODO, Bancor v2.1, v3 and Carbon,
Solidly-style pairs, and Ekubo:

| Pools touched in the transaction | Share of swap transactions |
| -------------------------------- | -------------------------- |
| 1                                | 69.1%                      |
| 2                                | 16.0%                      |
| 3                                | 7.4%                       |
| 4 or more                        | 7.5%                       |

That is 664,726 swap transactions at an average of **1.75 pools per swap**
(daily averages 1.64 to 1.87; a 1,000-block window on September 17 gave
1.68). Those transactions used 32.7% of all gas in the sampled blocks
(daily 20% to 41%). Transactions sent straight to the Uniswap and
1inch routers average 1.22 pools; the rest is aggregators, MEV and other
contracts. Failed transactions emit no logs and are excluded by construction.
Both figures are lower bounds: the count only sees swap events in the catalogued
families, so any AMM outside the catalogue adds uncounted transactions and
uncounted pools, and the swap-transaction gas share can only be higher. The
chain-wide capacity gains below inherit that bias and are underestimates.

A swap's transaction gas at _p_ pools is the one-pool minimal-router transaction
plus (_p_ − 1) times the measured marginal per extra pool:

| Average pools per swap | Ekubo       | Uniswap v4 | Uniswap v3 | Ekubo saving vs v4 / v3 |
| ---------------------- | ----------- | ---------- | ---------- | ----------------------- |
| **1.75 (measured)**    | **131,019** | 158,020    | 161,461    | **17.1% / 18.9%**       |
| 1.0                    | 112,997     | 131,284    | 117,006    | 13.9% / 3.4%            |
| 1.5                    | 125,044     | 149,156    | 146,722    | 16.2% / 14.8%           |
| 2.0                    | 137,091     | 167,027    | 176,438    | 17.9% / 22.3%           |

Block-space shares: over the 30 days ending September 17, 2026, mainnet burned
1,255.7 ETH of base fees (ultrasound.money), and transactions to known DEX
routers were about 4.2% of it, a lower bound that misses aggregators, MEV and
direct pool calls; ultrasound's coarser "defi" category was 19.4%. The
32.7% measured above counts every transaction that touched a pool,
including MEV and aggregator flow whose gas is mostly not swapping. The 70% share
was stipulated for this page as an "all AMM trading" upside case; it is an
assumption, not a measurement. If a swap's share of the burn equals its share of
gas and the saving applies to all of it, moving that slice to Ekubo frees the
share times the saving (each cell spans the saving against v3 and against v4):

| Block-space share given to swaps                  | Measured 1.75 pools (v3 18.9%, v4 17.1%) | 1 pool, production routers (v3 10.3%, v4 23.2%) | 2.0 pools (v3 22.3%, v4 17.9%) |
| ------------------------------------------------- | ---------------------------------------- | ----------------------------------------------- | ------------------------------ |
| 4.2%, measured DEX-router burn, lower bound       | 0.7–0.8%                                 | 0.4–1.0%                                        | 0.8–0.9%                       |
| 19.4%, "defi" category bracket                    | 3.3–3.7%                                 | 2.0–4.5%                                        | 3.5–4.3%                       |
| 32.7%, swap-event transactions, measured          | 5.6–6.2%                                 | 3.4–7.6%                                        | 5.9–7.3%                       |
| 70%, stipulated AMM-trading upside (not measured) | 12.0–13.2%                               | 7.2–16.2%                                       | 12.5–15.6%                     |

Induced demand would fill freed space. Read these as an order of magnitude, not a
forecast.

## On Base and Arbitrum

L2 fees are cheap L2 execution plus a charge for the L1 data the sequencer posts.
Both were measured on Base (block 51439900) and Arbitrum One (block 506178800)
for 100 USDC to WETH through each protocol's deployed contracts, warmed, on the
deepest live Uniswap WETH/USDC pool of each chain; no live Ekubo pool there could
absorb the swap, so the Ekubo leg runs on a pool created on the fork with the v3
pool's price, fee and liquidity. The L1 data component is what each chain's own
fee oracle charges for the exact transaction, in gas at the block's L2 base fee:

| Chain    | Leg (100 USDC to WETH)     | Execution gas | Calldata bytes | L1 data (gas-equivalent) | Total, incl. 21,000 base and calldata gas |
| -------- | -------------------------- | ------------- | -------------- | ------------------------ | ----------------------------------------- |
| Base     | Ekubo, Yul router          | **105,084**   | 184            | 331                      | **128,171**                               |
| Base     | Uniswap v3, SwapRouter02   | 121,803       | 228            | 319                      | 144,646                                   |
| Base     | Uniswap v4, minimal locker | 126,959       | 292            | 367                      | 150,694                                   |
| Arbitrum | Ekubo, Yul router          | **113,121**   | 184            | 561                      | **136,870**                               |
| Arbitrum | Uniswap v3, SwapRouter     | 130,896       | 260            | 603                      | 154,415                                   |
| Arbitrum | Uniswap v4, minimal locker | 135,006       | 292            | 644                      | 159,234                                   |

The mainnet pattern carries over: the whole transaction is 14.9% and 11.4%
cheaper than v4 and v3 on Base, 14.0% and 11.4% on Arbitrum, since both chains
run the same EVM at the same opcode prices. The data component decides nothing
at these blocks: 0.2% to 0.4% of every leg, and on Base not even smallest for
Ekubo, whose dense route compresses worse than Uniswap's zero-padded calldata.
Compact calldata buys nothing measurable while L1 data is this cheap.

## Why it is cheaper

- **Cheaper pool core.** One packed storage word and Q64 fixed-point math cost
  about 20k gas per swap, against 29k for v4's multi-slot state and 37k for v3's
  slot0, fee-growth and tick bookkeeping (lab flamegraphs in `benchmarks/`).
- **Net settlement.** Ekubo and v4 settle once per transaction (2 token transfers
  for a route of any length); v3 pays 2 per pool. On the production contracts
  each extra pool costs about 22k of execution on Ekubo, 34k on v4, 59k on v3.
- **Compact calldata.** The Yul router packs a single-pool route into 184 bytes;
  Uniswap's Universal Router needs 1,092 for a single v4 swap with its Permit2
  funding, v3's SwapRouter 260.

## Measured honestly

Providing liquidity is measured where providers actually touch it: production
position managers on the live USDC/USDT pools. Minting a new ~10,000 USDC/USDT
position costs 244,513 on Ekubo against 297,390 on v4 (17.8% less) and 381,653 on
v3 (35.9% less). One-time costs (pool creation, tick initialization, first-swap
accumulator writes) are excluded by design everywhere on this page, and the v4
Universal Router was measured only at one pool. Scope: EVM only, concentrated
pools, no hooks or extensions on any side — any v4 hook or Ekubo extension changes
every number here.

## How it was measured

- Production Ekubo Core, Positions and Yul router; Uniswap v3 factory and
  SwapRouter; v4 PoolManager and Universal Router, on a fork of the latest
  mainnet block at run time, four fresh ERC20 tokens, 0.3% pools of matched
  liquidity, no tick crossings.
- Warmed, isolated steady state: one identical unmeasured call first, every
  touched slot already nonzero, each measured call its own transaction, so the
  snapshot is execution gas net of refunds; exact calldata recorded per call.
- Minimal single-lock routers of the same shape on all sides for route scaling,
  which favors Uniswap: its production routers cost more than the minimal
  figures, Ekubo's costs less.
- L2s: Base and Arbitrum One forks pinned by block, deployed Uniswap routers and
  pools, the deployed Ekubo Yul router on a fresh pool mirroring the v3 pool; L1
  data read from each chain's fee oracle, not modeled.
- Pools per swap: a uniform 10% sample of a month of mainnet block receipts over
  public JSON-RPC, every event signature hashed from its protocol's source. Not
  counted: order-book and RFQ fills unless they land in a pool, the legacy Ekubo
  v2 core, long-tail AMMs. Sources, snapshots, calldata, pool identifiers and
  reproduction commands: `benchmarks/` in the docs repository.
