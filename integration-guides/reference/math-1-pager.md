---
description: A practical guide to Ekubo's internal math
---

# Math 1-pager

Ekubo represents the current state of each pool with two values: `sqrt_ratio` and `liquidity`. The `sqrt_ratio` represents the square root of the current price of the pool in terms of  `token1 / token0`, and the `liquidity` is a measure of how much of the two tokens is available for trading at the current price.

The price can be anywhere between `2**-128` and `2**128`, which means the square root of the price can be anywhere between `2**-64` and `2**64`. We use a [fixed point number](https://en.wikipedia.org/wiki/Fixed-point\_arithmetic) type for storing the price with 128 bits after the radix. A `sqrt_ratio` of `1` is represented as `1<<128`.

$$sqrt\_ratio = \sqrt{y/x}$$

$$liquidity = \sqrt{x*y}$$

The value `sqrt_ratio` is defined as `sqrt(y/x)` and `liquidity` is defined as `sqrt(x*y)`. This is a different method of tracking `x` and `y` in `x * y = k` that is much easier to think about when we introduce the concept of concentrated liquidity: the act of swapping only changes the price, and adding and removing `x` and `y` only updates the liquidity. With these two values defined as such, all other formulae can be derived from it (e.g.: the amount of `x` in the pool, the differences in `x`/`y` between prices, etc.)&#x20;

{% hint style="info" %}
Ekubo does not consider token decimals in any of its calculations. If `token0` and `token1` have different decimals, that just means the price of `1` is actually `10**token1_decimals / 10**token0_decimals.`
{% endhint %}

A constant-liquidity AMM such as Uniswap V2 can be trivially implemented using these representations instead of `x` and `y`, and Ekubo with full range liquidity is effectively a more efficient version of the traditional constant product AMM.

When the price moves due to swapping, positions are entered and exited, and Ekubo adjusts the liquidity mid-trade. Thus, trades must be executed iteratively: a user's swap is broken up into pieces trading through areas of the curve with constant liquidity. Each time we cross a position boundary, we update the current liquidity. How do we define position boundaries? That's where ticks come in.

Ticks divide the entire price range into discrete regions. They can be defined however an AMM designer wishes, but in Ekubo prices are divided up logarithmically so that each tick is equally spaced. The base of the log for Ekubo is set to `1.000001`. You can compute the `sqrt_ratio` corresponding to ticks using decimal math libraries, for example in TypeScript:

{% code title="tick_to_sqrt_ratio.ts" %}
```typescript
import {Decimal} from 'decimal.js-light';

const tick = 1234;

// A fixed point .128 number has at most 128 bits after the decimal, 
// which translates to about 10**38.5 in decimal.
// That means ~78 decimals of precision should be able to represent
// any price with full precision.
// Note there can be loss of precision for intermediate calculations,
// but this should be sufficient for just computing the price.
Decimal.set({ precision: 78 });

const sqrt_ratio_x128 = 
    new Decimal('1.000001')
        .sqrt()
        .pow(tick)
        .mul(new Decimal(2).pow(128));
```
{% endcode %}

The inverse can be computed (`tick` from `sqrt_ratio`), by doing taking the logarithm of `sqrt_ratio` in base `1.000001`.

Once you've broken up the price range into pieces, positions are just a combination of an amount of liquidity and lower/upper tick boundaries.
