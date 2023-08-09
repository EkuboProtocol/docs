---
description: What sets Ekubo Protocol apart from other AMM protocols
---

# Features

## Gas efficiency

Ekubo uses the till pattern and a singleton design to provide the cheapest trades against concentrated liquidity on Starknet. That means all the pools are managed in a single contract, and when you swap against a pool or update a position on Ekubo, token transfers are deferred until the end of the transaction.&#x20;

The result is that you can execute many actions across many pools and only transfer the required amounts of tokens. This, combined with Starknet's low fees, allows Ekubo protocol to provide the best execution net of gas.

## Concentrated liquidity

Concentrated liquidity allows market makers to provide liquidity within a specified price range. Each liquidity provider chooses the exact parameters of their position, but all positions in a pool are aggregated from a swapper's perspective. As a result, swappers get better pricing because liquidity providers can leverage up or earn yield on unused capital elsewhere.

## Extensions

Extensions allow third party developers to permissionlessly create new kinds of pools on Ekubo that integrate into the same ecosystem of aggregators and interfaces built on top of Ekubo. These pools can implement new features such as oracles, or new order types like limit orders or TWAMM orders. Read more about extensions [here](features.md#extensions).

## Withdrawal fee

When you withdraw liquidity from Ekubo, you pay a fee equal to the swap fee of the selected pool from your principal.

For example, consider the following scenario:

* You deposit 1000 USDC and 1 ETH into a 5 bips pool
* Several trades happen and you now have 2000 USDC and 0.5 ETH
  * You have also earned 20 USDC in fees and 0.005 ETH in fees
* You withdraw your liquidity

You will pay a 1 USDC and 0.00025 ETH fee from your principal. You can think of the withdrawal fee as paying a swap fee for rebalancing your liquidity.

Because this fee is taken on principal, it decreases as a percentage of _liquidity_ as position concentration increases. It also means that it's more expensive for other LPs to undercut your pricing. This fee prevents programmatic market makers from earning fee revenue whilst also rebalancing their inventory, thus protecting liquidity provider returns from MEV extraction.
