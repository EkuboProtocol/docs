---
description: >-
  Libraries for computing Ekubo quotes, working with pool math, and encoding
  swap routes
---

# SDKs

Ekubo publishes three libraries. All of them implement the same protocol math, so quotes computed off-chain match on-chain execution exactly.

| Package | Language | Use it for |
| --- | --- | --- |
| [`ekubo_sdk`](https://crates.io/crates/ekubo_sdk) | Rust | Computing quotes and simulating swaps across every pool type |
| [`@ekubo/sdk`](https://www.npmjs.com/package/@ekubo/sdk) | TypeScript | Pool math, tick and price conversions, pool key encoding |
| [`@ekubo/yul-router-sdk`](https://www.npmjs.com/package/@ekubo/yul-router-sdk) | TypeScript | Encoding swap routes for execution on EVM chains |

All three cover both Starknet and EVM deployments where the underlying math is shared.

## Rust: `ekubo_sdk`

The [Rust SDK](https://github.com/EkuboProtocol/rust-sdk) is the most complete implementation — it is what powers Ekubo's own routing. It exists primarily to **compute quotes** from Ekubo pools, plus the supporting protocol math.

```toml
[dependencies]
ekubo_sdk = { version = "3.2", features = ["evm"] }
```

The crate is `no_std`-compatible, which makes it usable in constrained environments. Select what you need with feature flags:

| Feature | Effect |
| --- | --- |
| `std` (default) / `no_std` | Standard library or `libm`-backed math; exactly one must be enabled |
| `evm` | EVM types via `alloy-primitives` (v1 by default; `evm-alloy-0_6` pins v0.6) |
| `starknet` | Starknet felt types via `starknet-types-core` |
| `serde` | Serialization for the protocol types |

Three modules:

* **`math`** — tick and sqrt-ratio conversions, swap step computation, deltas, fixed-point helpers, and TWAMM math
* **`quoting`** — the quoting engine: a `Pool` trait with a `quote` method, `QuoteParams` / `Quote` / `TokenAmount` types, and `PoolKey` / `PoolConfig` / `Tick` definitions
* **`chain`** — the EVM and Starknet type mappings

The `quoting::pools` module implements every pool type and extension so that off-chain quotes account for extension behavior: `concentrated`, `full_range`, `stableswap`, `limit_order`, `mev_capture`, `twamm`, `oracle`, `ve33`, `spline`, and `boosted_fees` variants. This is the practical reason to prefer the Rust SDK for routing — replicating extension behavior by hand is where most integrations go wrong (see [Aggregators](aggregators.md)).

## TypeScript: `@ekubo/sdk`

```sh
npm install @ekubo/sdk
```

Shared math and protocol encoding utilities, with **no runtime dependencies**. It covers the pieces most integrations need in a browser or Node environment:

* **Tick and price math** — conversions between ticks, sqrt ratios, and prices for both chains (see [Price representation](../concepts/price-representation.md))
* **Liquidity math** — `maxLiquidityForTokenAmounts`, `liquidityToAmountBase` / `liquidityToAmountQuote`, `amountsFromSpecifiedAmount`, and the `amount0Delta` / `amount1Delta` primitives for sizing positions
* **Swap math** — `computeStep`, `computeFee`, `amountBeforeFee`, `nextSqrtRatioFromAmount0` / `nextSqrtRatioFromAmount1`
* **TWAMM math** — `calculateNextSqrtRatio` for [DCA](../user-guides/dollar-cost-average-orders.md) pools
* **Pool key and protocol encoding** for EVM
* **Chain constants** — `EVM_MIN_TICK` / `EVM_MAX_TICK` (±88,722,835), `EVM_MAX_TICK_SPACING`, `EVM_MIN_SQRT_RATIO` / `EVM_MAX_SQRT_RATIO`, and the Starknet equivalents (±88,722,883)

{% hint style="info" %}
`@ekubo/sdk` is published as an alpha. Pin an exact version, and expect the surface to change before a stable release.
{% endhint %}

## TypeScript: `@ekubo/yul-router-sdk`

```sh
npm install @ekubo/yul-router-sdk
```

Encodes calldata for the [Yul Router](yul-router.md), the router used for Ekubo swaps on EVM chains. Use it to turn a route — typically one returned by the [Quoter API](../reference/quoter-api.md) — into a transaction. See the [Yul Router guide](yul-router.md) for the full surface and worked examples.
