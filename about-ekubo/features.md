---
description: What sets Ekubo Protocol apart from other AMM protocols
---

# 🔑 Features

## Free by default

The core contracts are ownerless and permissionless. They are deployed to the same address on every chain using a script that anyone can run. There is no protocol fee collection built into the Core contracts or any of the extensions--all generated fees go directly to users. Instead, any protocol fees are collected at the periphery. This is the key innovation that allows Ekubo V3 to service many different licensees.

## Gas efficiency

Ekubo uses the ["till" pattern](../integration-guides/till-pattern.md) and a singleton design to provide the cheapest trades against many pools all featuring concentrated liquidity. That means all the pools are managed in a single contract, and when you swap against a pool or update a position on Ekubo Protocol, token transfers are deferred until the end of the transaction. In fact, you don't have to transfer tokens at all--advanced swappers could save those tokens in Ekubo Protocol for later, avoiding expensive token transfers and undesirable token behavior altogether. Or they could mint the saved balance into a ERC-1155 token to re-use in Ekubo later.

The result is that you can execute many actions across many pools and only make the minimum number of required token transfers. The highly optimized and capital efficient design and ruthlessly optimized contracts enables Ekubo protocol to provide the best execution net of gas.

## Concentrated liquidity

Concentrated liquidity allows market makers to [provide liquidity](../user-guides/add-liquidity.md) within a specified price range. Each liquidity provider chooses the exact parameters of their position, but all positions in a pool are aggregated from a swapper's perspective. As a result, swappers get better pricing because liquidity providers can leverage up within a price range, _or_ earn yield on unused capital elsewhere.

Ekubo Protocol uses ticks 100x smaller than the competitors at 1/100th of a basis point. This allows $1,000 in liquidity in EKUBO to work as well as $100k in the next best AMM protocol.

## Extensions

Extensions allow third party developers to permissionlessly create new kinds of pools on Ekubo that integrate into the same ecosystem of aggregators and interfaces built on top of Ekubo. These pools can implement new features such as oracles, or additional order types like limit orders or TWAMM orders. Read more about extensions [here](../integration-guides/extensions.md).
