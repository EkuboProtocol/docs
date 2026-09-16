---
description: Measured gas costs for Ekubo swaps against Uniswap v4 and v3, with like-for-like benchmarks, scaling analysis, and mainnet-fork validation
title: "Gas efficiency"
---

Ekubo is designed to make trading cheap: one singleton contract holds every pool,
[flash accounting](/concepts/key-concepts/) settles only net differences, and pool
state packs into a single storage word. This page backs that design claim with
measured numbers — full methodology, harness sources, and flamegraphs included —
comparing Ekubo on EVM against Uniswap v4 and Uniswap v3 on identical workloads.

All figures are execution gas for a 0.3% concentrated-liquidity pool with a
wide-range position and no extension. Every measurement is taken on a warmed
pool: each test runs on a fresh chain, performs one identical unmeasured swap
first, then measures the second, so pools, tokens, and approvals sit in warmed
nonzero slots — the steady state a real pool lives in. Percentages beside the
tables add the 21,000 base fee plus exact calldata cost, i.e. full transaction
gas (the post-Pectra calldata floor was checked and does not bind at these
sizes).

## Single swaps

One token of input, exact-input, no tick crossings, 18-decimal plain ERC20 tokens
(the identical token contract runs in every harness):

| Swap                              | Ekubo      | Uniswap v4 | Uniswap v3                 |
| --------------------------------- | ---------- | ---------- | -------------------------- |
| ERC20 to ERC20                    | **87,416** | 103,548    | 87,553                     |
| ERC20 to ERC20, reverse direction | **86,334** | 103,373    | 86,952                     |
| Native ETH to ERC20               | **72,592** | 98,953     | — (v3 needs WETH wrapping) |

Warmed single hops are close: about **110k on Ekubo and v3 alike at the
transaction level, 127k on v4** — roughly 14% less than v4 and parity with v3.
The v4 figure uses a true-minimal locker (unlock, swap, settle net); v4's own
test helper costs more, and the production Universal Router costs more still.
The v3 figure is a direct pool call with zero router overhead, so it is a lower
bound; the production SwapRouter adds on top. A single swap is the one place
v3's heavier pool core (see below) is fully offset by having no router at all.

## How the gap scales with route length

Routing through one, two, and three pools in a single transaction, each protocol
using the same minimal single-lock router throughout, so the per-hop marginal is
apples-to-apples:

| Route length                     | Ekubo       | Uniswap v4  | Uniswap v3  |
| -------------------------------- | ----------- | ----------- | ----------- |
| 1 pool                           | 94,892      | 107,360     | 116,130     |
| 2 pools                          | 119,333     | 141,771     | 178,760     |
| 3 pools                          | 143,774     | 176,182     | 241,389     |
| **Marginal cost per extra pool** | **~24,400** | **~34,400** | **~62,600** |

The marginals are linear to the gas unit because each added hop hits an
identically shaped fresh pool with its own distinct token contracts. At three
pools Ekubo costs about 18% less than v4 and 40% less than v3 in execution gas.
This is where the architecture compounds: each extra Ekubo hop is little more
than one pool-math call, while v3 replays a full settle-and-callback cycle per
pool.

Token transfers tell part of the story. Ekubo and v4 both settle net inside one
lock, so a route of any length moves exactly 2 token transfers:

| Transfers per route | Ekubo     | Uniswap v4 | Uniswap v3 |
| ------------------- | --------- | ---------- | ---------- |
| 1 / 2 / 3 pools     | 2 / 2 / 2 | 2 / 2 / 2  | 2 / 4 / 6  |

V3 pays two transfers per pool (callback payment plus output) because every pool
is a separate contract that must be paid individually. But transfers alone do not
explain the v4 gap — v4 nets transfers exactly like Ekubo. The rest of the
difference is inside the pool core.

## Where the savings come from

Frame-level attribution of the warmed single-hop swap, from Foundry flamegraphs
(each capture is one warmed swap call; frame widths are proportional to gas):

![Flamegraph of an Ekubo single-hop swap](/gas/flamegraph-ekubo-single.svg)
_Flamegraph: Ekubo single-hop swap, 87,384 gas._

![Flamegraph of a Uniswap v4 single-hop swap](/gas/flamegraph-v4-single.svg)
_Flamegraph: Uniswap v4 single-hop swap via a minimal locker, 103,548 gas._

![Flamegraph of a Uniswap v3 single-hop swap](/gas/flamegraph-v3-single.svg)
_Flamegraph: Uniswap v3 single-hop swap via direct pool call, 87,575 gas._

| Component                              | Ekubo (87,416)              | Uniswap v4 (103,548)               | Uniswap v3 (87,553)               |
| -------------------------------------- | --------------------------- | ---------------------------------- | --------------------------------- |
| Pool math and state                    | Core swap: **20,331** (23%) | PoolManager swap: **28,884** (28%) | Pool internals: **~59,600** (68%) |
| Settlement (transfers plus accounting) | ~45,600                     | ~39,700                            | ~27,900                           |
| Router and lock overhead               | ~23,100                     | ~27,800                            | 0 (direct call)                   |

Three observations:

- **The pool core is where Ekubo wins.** One packed storage word and Q64
  fixed-point math cost about 20k per swap, against 29k for v4's multi-slot
  state with protocol-fee and donation bookkeeping, and about 60k for v3's
  slot0, fee-growth, and per-swap oracle writes.
- **Ekubo spends the savings back on settlement and routing.** Flash-accounting
  settlement (~46k) costs more than v4's (~40k) and v3's (~28k), and the
  Solidity Router's ABI round-trip (~23k) matches v4's lock overhead. On a
  single hop these cancel out against v3; the till pattern only pulls ahead as
  routes grow (see the transfer and marginal tables above).
- **Warmed pools matter.** An earlier cold-access variant of this comparison
  overstated the single-hop gap by about 17k on v4 and v3, because their pool
  state is cold-sensitive while Ekubo's is nearly warmth-invariant (verified:
  identical totals with and without warm-up, and with unrelated preceding
  operations). All figures above are warmed steady-state.

## Mainnet-fork validation

Lab harnesses control everything, so the same comparison was re-run where it
matters: one pair, production code, real liquidity. All three legs swap
1000 USDT to USDC on a mainnet fork (block 25991868), warmed, with negligible
tick movement (0–1 ticks):

| Swap on mainnet fork             | Ekubo       | Uniswap v4 | Uniswap v3 |
| -------------------------------- | ----------- | ---------- | ---------- |
| 1000 USDT to USDC, execution gas | **110,622** | 132,388    | 128,611    |

That is about 14% less than v3 and 16% less than v4, on the same pair and the
same size. Each leg uses its production path: Ekubo through the real deployed
Yul router against a live USDC/USDT pool with SDK-generated calldata, v3
through the real SwapRouter against the deepest fee-100 pool, v4 through the
real PoolManager against the deepest fee-100 pool with a minimal locker (the
Universal Router would cost more). Fee tiers differ across venues, which does
not affect the code path; output matched the production quoter within 0.02% on
the Ekubo leg.

## The mint exception

Providing liquidity is the one measured operation where Ekubo is not the
cheapest. Minting an economically matched position (1M tokens a side) as a
subsequent mint with boundary ticks already initialized, same tier of caller on
each protocol (direct-to-core, no NFT, no position manager):

| Mint path                  | Ekubo                 | Uniswap v4 | Uniswap v3  |
| -------------------------- | --------------------- | ---------- | ----------- |
| Bare / direct to core      | 179,020               | 162,188    | **121,430** |
| User-facing (NFT position) | 213,104 via Positions | —          | —           |

Ekubo's Positions NFT adds about 34k over the bare core path for minting, token
metadata, and protocol-fee accounting; production position managers add overhead
on all three protocols, and no v4/v3 manager path was measured here, so the NFT
row is harness-only context rather than a cross-protocol verdict. Cheap swaps
and relatively expensive mints are two sides of the same design: Core is
optimized for the operation that happens orders of magnitude more often.

## Methodology and limitations

- Each protocol compiles under its own production settings (Ekubo: solc 0.8.33,
  9999999 optimizer runs, via IR, Osaka; v4: v4-core's own settings; v3:
  canonical mainnet bytecode), with Foundry 1.8.3 throughout.
- One identical token artifact runs in every lab harness, and every recipient
  is pre-funded, so no measured call pays a zero-to-nonzero balance write that
  the others avoid.
- Routers are deliberately minimal on all sides, which favors Uniswap:
  production routers (Universal Router, SwapRouter, and Ekubo's own frontend
  path) all cost more than the numbers above.
- Scope is no-crossing swaps on hookless/extensionless pools: no Uniswap v4
  hooks, no Ekubo extensions, both swap directions covered, concentrated pools
  throughout.
- v3 per-hop figures exclude end-of-transaction refunds (about 4.8k per hop
  from clearing intermediate balances), so the true v3 marginal is closer to
  58k than 63k — the ranking is unaffected.
- Any v4 hook or Ekubo extension changes every number on this page; pool
  configuration (fee, tick spacing) barely moves them.

The complete harnesses, raw snapshots, flamegraphs, and reproduction commands
live in `benchmarks/` alongside these docs.
