---
description: >-
  How Ekubo represents pool prices: sqrt ratios, ticks, and the compact
  floating-point SqrtRatio type used by Ekubo V3 on EVM chains
---

# Price representation

Every Ekubo pool tracks its current price as a **square root ratio**: the square root of the price of `token1` in terms of `token0`.

$$
sqrt\_ratio = \sqrt{token1/token0}
$$

Working with the square root of the price (rather than the price itself) makes the concentrated liquidity math cheaper and more precise — see the [Math 1-pager](math-1-pager.md) for why. Prices are supported over the enormous range `[2^-128, 2^128]`, so the sqrt ratio always lies in `[2^-64, 2^64]`.

Ticks are the same on every deployment: tick `i` corresponds to the sqrt ratio `sqrt(1.000001^i)`, i.e. each tick is **1/100th of a basis point** of price. The valid tick range is roughly ±88.72 million (`±88,722,835` on EVM, `±88,722,883` on Starknet — the EVM range is very slightly narrower).

How the sqrt ratio is *encoded* differs between the Starknet and EVM deployments.

## Starknet: 64.128 fixed point

On Starknet, `sqrt_ratio` is a `u256` interpreted as a binary fixed-point number with **128 fractional bits**. A sqrt ratio of `1.0` (price of 1) is `2^128`. Since the sqrt ratio never exceeds `2^64`, the value always fits in 192 bits, which lets Core pack the pool price and tick into a single `felt252` storage slot.

* `MIN_SQRT_RATIO = 18446748437148339061` (≈ `2^-64 · 2^128`)
* `MAX_SQRT_RATIO = 6277100250585753475930931601400621808602321654880405518632` (≈ `2^64 · 2^128`)

To convert to a price: divide by `2^128`, then square. See [Reading pool price](reading-pool-price.md) for a worked example.

## EVM (V3): the floating-point `SqrtRatio` type

Ekubo V3 on EVM chains introduces a purpose-built **96-bit dynamic fixed-point type** — a compact floating-point-style encoding invented for Ekubo:

```solidity
type SqrtRatio is uint96;
```

### Why a float?

A full-precision 64.128 sqrt ratio needs 192 bits, which doesn't leave room for anything else in a 256-bit storage word. The AMM doesn't actually need 192 bits of precision at every magnitude — it needs *relative* precision. By encoding the sqrt ratio in 96 bits, the entire pool state packs into a **single storage slot**:

```
poolState (bytes32) = sqrtRatio (96 bits) | tick (32 bits) | liquidity (128 bits)
```

This makes updating pool state during a swap dramatically cheaper. The arithmetic on the type is designed so that any rounding error is biased in favor of the pool.

### Bit layout

The 96 bits consist of a **2-bit exponent selector** (bits 95–94) and a **94-bit mantissa** (bits 93–0). The exponent selects how the mantissa is interpreted as a binary fixed-point number:

| Exponent (bits 95–94) | Mantissa interpretation | Value range covered      |
| --------------------- | ----------------------- | ------------------------ |
| `00`                  | 0.126 (mantissa / 2^126)| sqrt ratios below `2^-32`|
| `01`                  | 0.94 (mantissa / 2^94)  | `2^-32` up to `1`        |
| `10`                  | 32.62 (mantissa / 2^62) | `1` up to `2^32`         |
| `11`                  | 64.30 (mantissa / 2^30) | `2^32` up to `2^64`      |

There is no implicit leading bit and no bias — each exponent value simply shifts the radix point by 32 bits. A sqrt ratio of exactly `1.0` is encoded with exponent `10` and mantissa `2^62`:

```solidity
SqrtRatio constant ONE = SqrtRatio.wrap(uint96((1 << 95) + (1 << 62)));
```

Key properties:

* **Monotonic**: a larger raw `uint96` always means a larger sqrt ratio, so comparisons are plain integer comparisons — no decoding required.
* **Normalized**: a valid value always has at least 62 significant mantissa bits (`isValid` requires the mantissa to be ≥ `2^62` and the raw value to be within the min/max bounds). Effective precision therefore ranges from 62 to 94 significant bits depending on where in the range the value falls — far more than enough for 1/100th-basis-point ticks.
* **Bounded**: `MIN_SQRT_RATIO` (raw `4611797791050542631`) through `MAX_SQRT_RATIO` (raw `79227682466138141934206691491`), corresponding to the same `[2^-64, 2^64]` sqrt ratio range as Starknet, i.e. prices in `[2^-128, 2^128]`.

### Converting to and from 64.128

The canonical "expanded" form on EVM is the same 64.128 fixed point used on Starknet. Conversion is a single shift, chosen by the exponent:

```solidity
// SqrtRatio -> 64.128 fixed point (uint256)
function toFixed(SqrtRatio sqrtRatio) pure returns (uint256);
// shift left by 2, 34, 66 or 98 bits for exponents 00, 01, 10, 11

// 64.128 fixed point -> SqrtRatio (rounding toward or away from zero)
function toSqrtRatio(uint256 sqrtRatioFixed, bool roundUp) pure returns (SqrtRatio);
```

Both directions round-trip losslessly for any valid `SqrtRatio`. To compute a human-readable price from the 64.128 value: divide by `2^128`, square, and adjust for the two tokens' decimals (worked example in [Reading pool price](reading-pool-price.md)).

### Where you'll encounter it

* **Swap parameters**: `sqrtRatioLimit` in swap params and router `RouteNode`s is a `SqrtRatio` (a value of `0` means "no limit").
* **Pool state and events**: `PoolInitialized` emits the initial `SqrtRatio`; extension hooks (`afterSwap`, `afterUpdatePosition`, ...) receive the packed pool state containing it.
* **Reading prices**: the `CoreDataFetcher` lens returns pool prices already expanded to 64.128 via `toFixed()`, so most integrators never need to decode the packed form manually.
* **SDKs**: [`@ekubo/sdk`](https://www.npmjs.com/package/@ekubo/sdk) (TypeScript) and the [Rust SDK](https://github.com/EkuboProtocol/rust-sdk) implement the exact tick and sqrt-ratio conversions for both Starknet and EVM.

## Fee encoding differs too

While ticks are chain-agnostic, the **pool fee** encoding differs between deployments:

| Deployment | Fee type | Denominator | Example: 0.3% |
| ---------- | -------- | ----------- | ------------- |
| Starknet   | `u128`, 0.128 fixed point | `2^128` | `1020847100762815411640772995208708096` |
| EVM (V3)   | `uint64`, 0.64 fixed point | `2^64` | `55340232221128654` |

In both cases the fee is a binary fraction of the full width — `fee / 2^128` (Starknet) or `fee / 2^64` (EVM) — applied to the swap input amount, rounded up in favor of the pool.
