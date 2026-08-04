---
description: >-
  How trading works on Ekubo: routing across every pool, quotes that account
  for extensions, and single-transaction execution
---

# Trading

A trade on Ekubo goes through three stages: finding a route, quoting it, and executing it. Each stage is available as public infrastructure you can use directly.

## Routing and quoting

Ekubo's liquidity is spread across pool types and [extensions](../concepts/extensions.md) — concentrated, stableswap, full-range, TWAMM, MEV capture, Ve33 — all inside the same Core contract. A good route often splits a trade across several of them.

The [Quoter API](../reference/quoter-api.md) does this for you. Given a chain, an amount, and a token pair, it returns **block-pinned split routes** for exact-input or exact-output swaps:

```
GET https://prod-api-quoter.ekubo.org/{chainId}/{amount}/{specifiedToken}/{otherToken}
```

A negative amount requests an exact-output quote. Token addresses and decimals resolve through the [Ekubo API](../reference/ekubo-api/README.md) token list.

Because quotes are pinned to a block, they reflect exact pool state at that block — including extension behavior, which is the part hand-rolled integrations most often get wrong.

## Simulation

If you need to compute quotes yourself — running your own solver, backtesting, or simulating without a network round-trip — the [SDKs](../integration-guides/sdks.md) implement the same math the contracts do.

The Rust SDK ([`ekubo_sdk`](https://crates.io/crates/ekubo_sdk)) is the most complete: its quoting module implements every pool type and extension, so simulated quotes match on-chain execution rather than approximating it. It is `no_std`-compatible, so it runs in constrained environments as well as on a server.

For pool math in TypeScript — tick and price conversions, liquidity sizing, swap steps — use [`@ekubo/sdk`](https://www.npmjs.com/package/@ekubo/sdk).

## Execution

On EVM chains, swaps execute through the [Yul Router](../integration-guides/yul-router.md), deployed at the same address on every supported chain. Routes are encoded with [`@ekubo/yul-router-sdk`](https://www.npmjs.com/package/@ekubo/yul-router-sdk) and sent as raw calldata — there is no ABI selector, because the calldata *is* the route.

The router executes every split of a trade under a **single Core lock**, aggregates the amounts, applies **one slippage check** against the total, and settles token transfers once. This is what makes multi-pool routing on Ekubo cheap: [flash accounting](../concepts/architecture.md) means intermediate hops never touch the token contracts.

Trading from your own contract on either chain follows the same lock-and-callback flow — see [Swapping](../integration-guides/swapping.md).

## Trade types beyond spot

* **[DCA orders](../user-guides/dollar-cost-average-orders.md)** — sell a token gradually over a period, netted against opposing orders, using the TWAMM extension
* **Limit orders** — one-tick positions that execute at a chosen price and are pulled automatically once filled
* **[Signed exclusive swaps](../integration-guides/signed-exclusive-swaps.md)** — RFQ-style pools where a market maker signs each quote off-chain with its own fee and bounds

## MEV capture

The MEV capture extension charges an additional fee on swaps that move a pool's price significantly, and directs that value back to the pool's liquidity providers rather than to searchers. Pools using it are routed and quoted like any other pool.
