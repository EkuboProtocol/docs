---
description: Some things you should know before you get started
---

# Key Concepts

## Automated Market Maker (AMM)

An AMM is a common primitive in decentralized finance that allows users with capital to enter a position where they will allow users to trade with their capital as long as they pay some fees to cover the risk they are taking. The conditions under which these automated strategies trade varies. Some use a formula that is suitable for stable pairs, a la Curve, where others use formulas more suitable for volatile pairs. Many designs are based on the constant product formula.&#x20;

As long as fees from the trading volume outweigh the loss due to making bad trades, capital providers should earn yield. However, this is not always the case. One can think of depositing into an AMM as making a bet that trading fees will outweigh the loss due to price divergence.

## Constant product

This refers to the `x*y=k` formula that forms the basis of most AMMs, where `x` is amount of one token, i.e. `token0`, and `y` is the amount of the other, `token1`, and `k` is held constant as users trade with the pool. This formula is how trades are computed on Ekubo within regions of constant liquidity.

## Concentrated Liquidity

This is the main feature that allows Ekubo to provide better pricing than other AMMs. In simple constant product AMMs, any capital you deposit can be used to trade at any price, i.e. at any ratio of `x` to `y`. For example, if you deposit into the ETH-USDC pair of an AMM that does not have concentrated liquidity, you are expressing the position that you are willing to sell ETH at a price of one billion USDC or more, or buy ETH at a price of 0.00001 cents or less. It's hard to imagine these scenarios happening, but because the AMM must take custody of all the funds to support these situations, you must deposit capital to cover these cases.&#x20;

In contrast, concentrated liquidity AMMs allow you to specify the price range in which you are willing to trade with each position you take. For example, if you think ETH will only trade between the prices of 1800-2200 USDC/ETH, you can market make in that price range and forego depositing capital to support trades below or above that price range. What you do with that extra capital is up to you! You could simply use it to create more liquidity within that price range, amplifying both the amount of fees earned and your loss due to price divergence.

### Capital efficiency

Because you only need to provide principal for trading in the selected price range, you are earning the same fees for less principal. Capital efficiency is a measure of this leverage effect, i.e. how much more principal you would have to deposit into a full range position to earn the same amount of fees.

### Ticks

Ticks are simply discrete points on the price range used to break up the full range of possible prices, for placement of positions. They could be defined in any way, but the most uniform way to break up the price range is with some value to the power of the tick. This way each tick represents an `x%` increase. In Ekubo, that tick size is `1.000001`, or 1/100th of a basis point. This is smaller than most centralized limit order books, or CLOBs! In other words, that means you can place your positions at prices more specific than you can on centralized exchanges.

#### Tick spacing

It doesn't make sense to use the same tick size for every pool. Rather than having multiple different tick sizes, Ekubo's solution to this problem is to define a tick spacing for each pool. This means for more volatile pairs where a tiny price movement is not relevant to most traders, you can trade more efficiently.

