---
description: Some things you should know before you get started
---

# Key Concepts

## Ethereum

[Ethereum](https://ethereum.org/en/) is a blockchain that allows for "smart contracts": autonomous programs that anyone can deploy and use.

## Layer 2

A layer 2 is a network that uses Ethereum to provide a more scalable platform for applications without sacrificing on decentralization or security. The best layer 2 platforms provide similar security guarantees to Ethereum for much lower cost.

## ZK Proofs

See the [wikipedia](https://en.wikipedia.org/wiki/Zero-knowledge\_proof).

## Starknet

Starknet is a layer 2 network that uses a type of zero-knowledge proof called STARKs built by Starkware to allow users to transact at a much lower cost.

Because Starknet is built with scalability and usability in mind, your usual Ethereum wallets are not compatible with Starknet.

## Automated Market Maker (AMM)

An AMM is a common primitive in decentralized finance that allows users with capital to enter a position where they will allow users to trade with their capital as long as they pay fees. Different market makers implement different strategies for trading. Some use a formula that is suitable for stable pairs, a la Curve, where others use formulas more suitable for volatile pairs. Many designs are based on the constant product formula.

As long as fees from the trading volume outweigh the loss due to bad automated trades, liquidity providers see positive returns. However, this is not always the case. One can think of depositing into an AMM as making a bet that trading fees will outweigh the loss due to price divergence of the two assets in a pair.

## Constant product

This refers to the `x*y=k` formula that forms the basis of most AMMs, where `x` is amount of one token, i.e. `token0`, and `y` is the amount of the other, `token1`, and `k` is held constant as users trade with the pool. This formula is how trades are computed on Ekubo within regions of constant liquidity.

## Concentrated Liquidity

This is the main feature that allows Ekubo to provide better pricing than other AMMs. In simple constant product AMMs, any capital you deposit can be used to trade at any price, i.e. at any ratio of `x` to `y`. For example, if you deposit into the ETH-USDC pair of an AMM that does not have concentrated liquidity, you are expressing the position that you are willing to sell ETH at a price of one billion USDC or more, or buy ETH at a price of 0.00001 cents or less. It's hard to imagine these scenarios happening, but because the AMM must take custody of all the funds to support these situations, you must deposit capital to cover these cases.&#x20;

In contrast, concentrated liquidity AMMs allow you to specify the price range in which you are willing to trade with each position you take. For example, if you think ETH will only trade between the prices of 1800-2200 USDC/ETH, you can market make in that price range and forego depositing capital to support trades below or above that price range. What you do with that extra capital is up to you! You could simply use it to create more liquidity within that price range, but beware this amplifies **both** the amount of fees earned _and_ your losses due to price divergence.

### Capital efficiency

Because you only need to provide principal for trading in the selected price range, you are earning the same fees for less principal. Capital efficiency is a measure of this leverage, i.e. how much more capital you would have to deposit into a full range position to earn the same amount of fees.

### Ticks

Ticks correspond to specific prices, used to specify boundaries for positions. They could be defined in any way, but the most uniform way to break up the price range is with some value to the power of the tick. This way each tick represents an `x%` increase.&#x20;

In Ekubo, the tick size is `1.000001`, or 1/100th of a basis point. This is smaller than most centralized limit order books. In other words, that means you can create one-tick positions, similar to limit orders, at prices more specific than you could on centralized exchanges. This makes Ekubo a great place to build an order book.

#### Tick spacing

The minimum amount of space between ticks used by a position. This is specified on a per-pool basis, and is used to optimize the computation cost of swaps. A lower tick spacing should be used for pools that do not experience large price movements, and vice versa.

Because pairs have differing amounts of volatility, it doesn't make sense to use the same tick size for every pool. Rather than having multiple different tick sizes, Ekubo's solution to this problem is to define a tick spacing for each pool. For more volatile pairs where a small price movement is not relevant, you can trade more efficiently by specifying a higher tick spacing.

## Flash accounting

This refers to doing all token balance accounting internally within Ekubo, before transferring any tokens. This means you can trade with many pools and create/update as many positions as you like and only transfer the difference at the end. This is amazingly efficient for tasks like arbitrage or creating many positions, which is key to market efficiency.

#### Free flash loans

Because of flash accounting, you can simply `#withdraw` tokens from the singleton contract and then `#deposit` them in the same transaction without paying any fees.

