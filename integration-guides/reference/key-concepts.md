---
description: Useful concepts and technologies on which Ekubo is built
---

# Key concepts

## Ethereum

[Ethereum](https://ethereum.org/en/) is a blockchain that allows for "smart contracts": autonomous programs that anyone can deploy and use.

## Layer 2

A layer 2 is a network that uses Ethereum to provide a more scalable platform for applications without sacrificing on decentralization or security. The best layer 2 platforms provide similar security guarantees to Ethereum for much lower cost. Websites such as [L2BEAT](https://l2beat.com/) track the status of L2s and how they score among multiple dimensions.

## ZK Proofs

ZK stands for "zero knowledge," and is the technology used by [Starknet](key-concepts.md#starknet) to scale [Ethereum](key-concepts.md#ethereum). It enables the Starknet protocol to verify the correctness of state transitions on Ethereum without re-executing all the involved transactions or even including their data on Ethereum. See the [wikipedia](https://en.wikipedia.org/wiki/Zero-knowledge_proof).

## Starknet

Starknet is a layer 2 network that uses a type of zero-knowledge proof called STARKs built by [Starkware](https://starkware.co/) to allow users to transact at a much lower cost.

Because Starknet is built on top of a language called [Cairo](https://www.cairo-lang.org/), your usual Ethereum wallets are not yet compatible with Starknet. Wallets such as [Argent X](https://www.argent.xyz/argent-x/) and [Braavos](https://braavos.app/) work exclusively with Starknet.

## Automated Market Maker (AMM)

A decentralized finance product that allows users to automatically "buy low, sell high." AMMs differ primarily in the amount of customization available to liquidity providers and the strategies themselves. Some use a formula that is suitable for stable pairs, a la [Curve](https://curve.fi/), where others use formulas more suitable for volatile pairs. Many designs are based on the [constant product](key-concepts.md#constant-product) formula.

As long as fees from the trading volume outweigh the loss due to bad trades, liquidity providers see positive returns. However, it is hotly debated whether providing liquidity on an AMM is a generally profitable endeavor. One can think of depositing into an AMM as making a bet that trading fees will outweigh the loss due to price divergence of the two assets in a pair.

## Constant product

This refers to the `x*y=k` formula that forms the basis of most [AMMs](key-concepts.md#automated-market-maker-amm), where `x` is amount of one token, i.e. `token0`, and `y` is the amount of the other, `token1`, and `k` is held constant as users trade with the pool. This formula is how trades are computed on Ekubo within regions of constant liquidity.

## Concentrated liquidity

This is the main feature that allows Ekubo to provide better pricing than other AMMs. In simple constant product AMMs, any capital you deposit can be used to trade at any price, i.e. at any ratio of `x` to `y`. In contrast, concentrated liquidity AMMs allow you to specify the price range in which you are willing to trade with each position you take.

For example, if you deposit into the ETH-USDC pair of an AMM that does not have concentrated liquidity, you are expressing the position that you are willing to sell ETH at any price, including prices >$1B and <$0.000001. These scenarios are unrealistic, but because the simplified AMM must be solvent at any price, you must deposit capital to cover these cases.

An AMM featuring concentrated liquidity would allow you to provide liquidity in a specified price range. If you think ETH will only trade between the prices of 1800-2200 USDC/ETH, you can provide liquidity _only_ in that price range and forego depositing capital to support trades below or above that price range. What you do with that extra capital is up to you! You could even use it to leverage up within that price range to earn more fees, but beware this also amplifies your losses due to price divergence.

### Capital efficiency

If you provide [concentrated liquidity](key-concepts.md#concentrated-liquidity), you only need to provide principal for trading in the selected price range, thus you are earning the same fees for less principal. Capital efficiency is a measure of this leverage, i.e. how much more capital you would have to deposit into a full range position to earn the same amount of fees.

### Ticks

Ticks correspond to exact prices which can be used to specify boundaries for positions. Position boundaries are specified as ticks rather than arbitrary prices so the AMM can more efficiently process swaps. Ticks could be defined arbitrarily, but the most uniform way to break up the entire price range is in log-space.

In Ekubo, the tick size is `1.000001`, or 1/100th of a basis point. You can get the price by raising `1.000001` to the power `tick`. This level of precision is smaller than most centralized limit order books. In other words, that means you can create one-tick positions, similar to limit orders, at prices more specific than you could on centralized exchanges. This makes Ekubo a great place to build an on-chain order book.

#### Tick spacing

The minimum amount of space between ticks used by a position. This is specified on a per-pool basis, and is used to optimize the computation cost of swaps. A lower tick spacing should be used for pools that do not experience large price movements, and vice versa.

Because pairs have differing amounts of volatility, it doesn't make sense to use the same tick size for every pool. Rather than having multiple different tick sizes, Ekubo's solution to this problem is to define a tick spacing for each pool. For more volatile pairs where a small price movement is not relevant, you can trade more efficiently by specifying a higher tick spacing.

## Flash accounting

This refers to doing all token balance accounting internally within Ekubo, before transferring any tokens. This means you can trade with many pools and create/update as many positions as you like and only transfer the difference at the end. This is amazingly efficient for tasks like arbitrage or creating many positions, which is key to market efficiency.

Traditionally when trading with a single AMM pool, you must pay for each swap or position update immediately, even if you make multiple swaps or complicated multi-hop swaps in the same transaction.

#### Free flash loans

Because of flash accounting, you can simply `#withdraw` tokens from the singleton contract and then `#deposit` them in the same transaction without paying any fees.

