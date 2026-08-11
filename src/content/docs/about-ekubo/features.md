---
description: What sets Ekubo Protocol apart from other AMM protocols
title: "Features"
---

## Free by default

The core contracts are ownerless and permissionless. They are deployed to the same address on every chain using a script that anyone can run. Core itself collects no protocol fee — swap fees accrue entirely to the pool. Protocol fees, where they exist, are applied at the periphery, for example by the Positions contract when a provider collects their fees. This is the key design decision that allows Ekubo V3 to serve many different [licensees](/about-ekubo/v3-whitepaper/) on one shared liquidity layer.

## Gas efficiency

Ekubo uses the ["till" pattern](/concepts/architecture/) and a singleton design to provide the cheapest trades across many pools. All pools live in a single contract, and token transfers are deferred until the end of the transaction. Advanced users don't have to transfer tokens at all: balances can be saved inside Ekubo for later use, avoiding repeated token transfers entirely.

The result is that you can execute many actions across many pools while making only the minimum number of token transfers. Combined with contracts optimized down to the storage-slot and calldata level (see [Price representation](/reference/price-representation/)), this keeps the gas cost of a trade low, which matters most for routes that touch several pools.

## Concentrated liquidity

Concentrated liquidity allows market makers to [provide liquidity](/user-guides/add-liquidity/) within a specified price range. Each liquidity provider chooses the exact parameters of their position, but from a swapper's perspective all positions in a pool are aggregated into a single curve. Concentrating liquidity near the market price deepens the book where trades actually happen, so swappers see less price impact — and providers are free to deploy the capital they did not have to post elsewhere.

Ekubo's ticks are 1/100th of a basis point — 100 times finer than the usual concentrated-liquidity convention. Finer ticks make narrower ranges expressible, so a position can be placed precisely where the provider wants it. A narrower range concentrates the same capital into less price space, which raises the fees earned per dollar of principal _while the price stays in range_ — and equally raises the rate at which the position converts into the losing asset when the price moves against it, and the frequency with which it goes out of range entirely.

## Multiple pool types

Beyond concentrated liquidity, Ekubo V3 pools can be configured as stableswap pools (liquidity concentrated around a center price with an amplification factor) or full-range pools — all in the same Core contract, sharing the same routing and integration surface.

## Extensions

[Extensions](/concepts/extensions/) allow third-party developers to permissionlessly create new kinds of pools on Ekubo that plug into the same ecosystem of aggregators and interfaces. Deployed extensions include price [oracles](/reference/contracts/evm-v3/), TWAMM ([DCA orders](/user-guides/dollar-cost-average-orders/)), limit orders, MEV capture, and [Ve33](/products/ve33/) token-governed liquidity.

For what you can actually do with all of this — trading, providing liquidity, running incentive campaigns, indexing the data — see [Products](/products/).
