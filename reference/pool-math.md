---
description: >-
  Where to learn the concentrated-liquidity math Ekubo uses, and the parameters
  that are specific to Ekubo
---

# Pool math

Ekubo's concentrated liquidity pools use the same underlying math as other concentrated-liquidity AMMs: a constant-product curve where each position is active only within a price range, pool state tracked as a square-root price and a liquidity value, and swaps executed piecewise across regions of constant liquidity.

That math is well documented elsewhere, and the derivations are identical, so this page does not restate them. What it does cover is **the parameters that are specific to Ekubo** — the numbers you need to get right when implementing against it.

## Learn the math

| Reference | Best for |
| --- | --- |
| [Uniswap v3 whitepaper](https://app.uniswap.org/whitepaper-v3.pdf) | The canonical statement of the model — sections 6.1–6.3 cover ticks, swapping within a tick, and crossing ticks |
| [Liquidity Math in Uniswap v3](https://atiselsts.github.io/pdfs/uniswap-v3-liquidity-math.pdf), Atis Elsts | The clearest derivation of the position and amount formulas, worked step by step |
| [Uniswap v3 Development Book](https://uniswapv3book.com/) | A build-it-yourself walkthrough, if you learn best from implementation |
| [Concentrated liquidity](https://docs.uniswap.org/concepts/protocol/concentrated-liquidity) | A short conceptual introduction |

For the concepts in plain language without the formulas, see [Key concepts](../concepts/key-concepts.md).

## What Ekubo does differently

### Tick base

Ekubo's tick base is **`1.000001`**, not `1.0001`. Tick `i` corresponds to the price `1.000001^i`, so one tick is 1/100th of a basis point — 100 times finer than the more common convention. Every tick-to-price conversion you take from an external reference must use this base.

The tick range is correspondingly wider:

| | EVM (V3) | Starknet |
| --- | --- | --- |
| Min / max tick | ±88,722,835 | ±88,722,883 |
| Max tick spacing | 698,605 | 354,892 |

### Price and sqrt-ratio range

Ekubo supports prices from `2^-128` to `2^128`, so the square root of the price ranges from `2^-64` to `2^64`.

### Representation

The square-root price is stored differently on each deployment: a 128-bit fixed-point number on Starknet, and a compact 96-bit floating-point-style type on EVM. Fees are encoded as binary fractions, with a different denominator on each chain. Both are documented in [Price representation](price-representation.md) — read that before implementing any conversion.

### Token decimals

Ekubo performs no decimal adjustment anywhere in its math. If `token0` and `token1` have different decimals, a raw price of `1` corresponds to a human-readable price of `10**token1_decimals / 10**token0_decimals`. See [Reading pool price](../integration-guides/reading-pool-price.md) for a worked conversion.

### Other pool types

Concentrated liquidity is one of three pool types. **Stableswap** pools concentrate liquidity around a configurable center tick with an amplification factor, and **full-range** pools span the entire price range — the cheapest configuration, and equivalent to a constant-product AMM. See [Providing liquidity](../products/liquidity.md).

## Reference implementations

Rather than reimplementing the conversions, use an SDK — both handle Starknet and EVM, and both produce exactly the values the contracts use:

* [`ekubo_sdk`](https://crates.io/crates/ekubo_sdk) (Rust) — full quoting across every pool type and extension
* [`@ekubo/sdk`](https://www.npmjs.com/package/@ekubo/sdk) (TypeScript) — tick, price, liquidity, and swap math

See [SDKs](../integration-guides/sdks.md).
