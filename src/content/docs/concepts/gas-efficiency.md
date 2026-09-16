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
wide-range position and no extension, measured with Foundry snapshots where each
test runs isolated with every contract cooled, so each number is a cold-access
transaction. Percentages beside the tables add the 21,000 base fee plus exact
calldata cost, i.e. full transaction gas (the post-Pectra calldata floor was
checked and does not bind at these sizes).

## Single swaps

One token of input, exact-input, no tick crossings, 18-decimal plain ERC20 tokens
(the identical token contract runs in every harness):

| Swap                              | Ekubo      | Uniswap v4 | Uniswap v3                 |
| --------------------------------- | ---------- | ---------- | -------------------------- |
| ERC20 to ERC20                    | **87,384** | 120,648    | 104,653                    |
| ERC20 to ERC20, reverse direction | **86,334** | 120,473    | 106,848                    |
| Native ETH to ERC20               | **72,560** | 116,053    | — (v3 needs WETH wrapping) |

At the transaction level (base fee plus calldata included), the ERC20 swap costs
about **110k on Ekubo, 144k on v4, and 127k on v3** — roughly 24% less than v4
and 14% less than v3 for a single hop. The v4 figure uses a true-minimal locker
(unlock, swap, settle net); v4's own test helper costs more, and the production
Universal Router costs more still. The v3 figure is a direct pool call with zero
router overhead, so it is a lower bound; the production SwapRouter adds on top.

## How the gap scales with route length

Routing through one, two, and three pools in a single transaction, each protocol
using the same minimal single-lock router throughout, so the per-hop marginal is
apples-to-apples:

| Route length                     | Ekubo       | Uniswap v4  | Uniswap v3  |
| -------------------------------- | ----------- | ----------- | ----------- |
| 1 pool                           | 94,860      | 141,560     | 129,810     |
| 2 pools                          | 119,269     | 193,071     | 206,120     |
| 3 pools                          | 143,678     | 244,582     | 282,429     |
| **Marginal cost per extra pool** | **~24,400** | **~51,500** | **~76,300** |

The marginals are linear to the gas unit because each added hop hits an
identically shaped fresh pool with its own distinct token contracts. At three
pools Ekubo costs about 41% less than v4 and 49% less than v3 in execution
gas — the gap widens with every pool because each extra Ekubo hop is little
more than one pool-math call (see below).

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

Frame-level attribution of the single-hop swap above, from Foundry flamegraphs
(total height is total gas; each frame shows its own cost):

![Flamegraph of an Ekubo single-hop swap](/gas/flamegraph-ekubo-single.svg)
_Flamegraph: Ekubo single-hop swap, 87,384 gas._

![Flamegraph of a Uniswap v4 single-hop swap](/gas/flamegraph-v4-single.svg)
_Flamegraph: Uniswap v4 single-hop swap via a minimal locker, 120,648 gas._

![Flamegraph of a Uniswap v3 single-hop swap](/gas/flamegraph-v3-single.svg)
_Flamegraph: Uniswap v3 single-hop swap via direct pool call, 104,653 gas._

| Component                              | Ekubo (87,384)              | Uniswap v4 (120,648)                                           | Uniswap v3 (104,653)              |
| -------------------------------------- | --------------------------- | -------------------------------------------------------------- | --------------------------------- |
| Pool math and state                    | Core swap: **20,331** (23%) | PoolManager swap: **45,984** (38%), of which pool logic 36,388 | Pool internals: **~76,700** (73%) |
| Settlement (transfers plus accounting) | ~45,600                     | ~40,600                                                        | ~38,400                           |
| Router and lock overhead               | ~26,000                     | ~28,000                                                        | 0 (direct call)                   |

Three observations:

- **The pool core is where Ekubo wins.** One packed storage word and Q64 fixed-point
  math cost about 20k per swap, against 46k for v4's multi-slot state with
  protocol-fee and donation bookkeeping, and about 77k for v3's slot0, fee-growth,
  and per-swap oracle writes.
- **Settlement is rough parity.** All three move two tokens for a single hop at a
  similar cost; Ekubo's till pattern only pulls ahead as routes grow (see the
  transfer table above).
- **The Solidity Router's ABI round-trip (~26k) is Ekubo's largest single chunk.**
  These numbers use the Solidity Router as the conservative path; production
  traffic goes through the gas-optimized Yul router.

## Mainnet-fork validation

Lab harnesses control everything, which invites the question of whether the
ranking survives production bytecode, real tokens, and real liquidity. As a
check, the same 1-WETH-to-USDC swap was run on a mainnet fork (block 25991868,
all addresses verified on-chain):

| Swap on mainnet fork          | Ekubo      | Uniswap v4 | Uniswap v3 |
| ----------------------------- | ---------- | ---------- | ---------- |
| 1 WETH to USDC, execution gas | **98,066** | 175,461    | 142,287    |

That is 31% less than v3 and 44% less than v4, wider than the lab single-hop
gaps. Part of the widening is expected: the lab uses lightweight mock tokens
while the fork pays real-token costs (USDC is a proxy), real concentrated ticks,
and production routers. Two asymmetries to read alongside it: the Uniswap legs
use real concentrated pools — the v4 leg crossed about twelve initialized ticks,
which is genuinely part of trading on real liquidity — while the Ekubo leg uses
a freshly capitalized concentrated pool of the same shape as the lab tests. And
the v4 leg uses a minimal locker rather than the Universal Router, which would
cost more, while the v3 leg uses the real production SwapRouter. The fork confirms the
direction and rough magnitude of the lab result under production conditions; the
lab tables above are the controlled comparison.

As a version check, the fork swap was also run against a freshly deployed
worktree Core on the same fork state: byte-identical gas (98,066), so nothing
about the deployed Core vintage affects the comparison.

## The mint exception

Providing liquidity is the one measured operation where Ekubo is not the
cheapest. Minting a wide-range position, same tier of caller on each protocol
(direct-to-core, no NFT, no position manager):

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
- Routers are deliberately minimal on all sides, which favors Uniswap:
  production routers (Universal Router, SwapRouter, and Ekubo's own frontend
  path) all cost more than the numbers above.
- Scope is no-crossing swaps on hookless/extensionless pools: no Uniswap v4
  hooks, no Ekubo extensions, both swap directions covered, concentrated pools
  throughout (an early full-range-pool variant measured within 5k of these
  figures and was dropped for exactness). Every mint measured is a subsequent
  mint into a pool whose boundary ticks are already initialized, on all three
  protocols.
- v3 per-hop figures exclude end-of-transaction refunds (about 4.8k per hop from
  clearing intermediate balances), so the true v3 marginal is closer to 71k
  than 76k — the ranking is unaffected.
- Any v4 hook or Ekubo extension changes every number on this page; pool
  configuration (fee, tick spacing) barely moves them.

The complete harnesses, raw snapshots, and reproduction commands live in
`benchmarks/` alongside these docs.
