---
description: What sets Ekubo Protocol apart from the rest
---

# Features

## Gas efficiency

Ekubo is a singleton AMM. That means all the pools are managed in a single contract. When you swap against a pool or update a position on Ekubo, token transfers are deferred until the end of the transaction. So you can swap against many pools and only do a single token transfer. The result is maximally efficient aggregation across pools, as well as making it far cheaper to create many positions on different pools.

This, on top of being deployed to Starknet, is one of the reasons Ekubo can provide the best pricing net of gas, where "pricing net of gas" refers to the price you paid after considering gas fees.

## Concentrated liquidity

Never seen before on Starknet, concentrated liquidity allows market makers to provide liquidity within a specific price range. Each liquidity provider chooses the exact parameters of their position, but all positions in a pool are aggregated from a swapper's perspective. This means swappers can

## Withdrawal fee

When you withdraw liquidity from Ekubo, you pay a fee equal to the swap fee on your principal. In other words, if you deposit liquidity into the 5 bips fee tier, you pay a 5 bips fee on withdrawal.

For example, if you deposit 1000 USDC and 1 ETH into a 5 bips pool, several trades happen and you now have 2000 USDC and 0.5 ETH, and then you decide to withdraw, you will pay a 0.5 USDC and 0.00025 ETH fee. You can think of it as paying a swap fee for rebalancing your liquidity.

Because this fee is taken on principal, it decreases as a percentage of liquidity as position concentration increases. It also means that it's more expensive for other LPs to undercut your pricing. This fee also prevents programmatic market makers from earning fee revenue whilst also rebalancing their inventory, thus protecting liquidity provider returns from MEV extraction by competing market makers. We encourage you to use all the data at your disposal to select the best fee tier.

## Extensions

Extensions allow third party developers to permissionlessly create new kinds of pools on Ekubo that integrate into the same ecosystem of aggregators and interfaces built on top of Ekubo. These pools can implement new features such as oracles, or new order types like limit orders or TWAMM orders.
