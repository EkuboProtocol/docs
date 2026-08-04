---
description: What sets Ekubo Protocol apart from other AMM protocols
---

# Features

### Free by default

The core contracts are ownerless and permissionless. They are deployed to the same address on every chain using a script that anyone can run. There is no protocol fee collection built into the Core contracts or any of the extensions — all generated fees go directly to users. Protocol fees, where they exist, are collected at the periphery (for example by the Positions contract). This is the key design decision that allows Ekubo V3 to serve many different [licensees](v3-whitepaper.md) on one shared liquidity layer.

### Gas efficiency

Ekubo uses the ["till" pattern](../concepts/architecture.md) and a singleton design to provide the cheapest trades across many pools, all featuring concentrated liquidity. All pools live in a single contract, and token transfers are deferred until the end of the transaction. Advanced users don't have to transfer tokens at all: balances can be saved inside Ekubo for later use, avoiding repeated token transfers entirely.

The result is that you can execute many actions across many pools and only make the minimum number of required token transfers. Combined with contracts optimized down to the storage-slot and calldata level (see [Price representation](../concepts/price-representation.md)), Ekubo provides the best execution net of gas.

### Concentrated liquidity

Concentrated liquidity allows market makers to [provide liquidity](../user-guides/add-liquidity.md) within a specified price range. Each liquidity provider chooses the exact parameters of their position, but all positions in a pool are aggregated from a swapper's perspective: swappers get better pricing because liquidity providers can leverage up within a price range, or earn yield on unused capital elsewhere.

Ekubo's ticks are 1/100th of a basis point — 100x finer than most concentrated-liquidity AMMs. Finer ticks mean tighter ranges are possible, so the same capital can be concentrated where it is actually needed and achieve far greater capital efficiency than on coarser-tick AMMs.

### Multiple pool types

Beyond concentrated liquidity, Ekubo V3 pools can be configured as stableswap pools (liquidity concentrated around a center price with an amplification factor) or full-range pools — all in the same Core contract, sharing the same routing and integration surface.

### Extensions

[Extensions](../concepts/extensions.md) allow third-party developers to permissionlessly create new kinds of pools on Ekubo that plug into the same ecosystem of aggregators and interfaces. Deployed extensions include price [oracles](../reference/contracts/evm-v3.md), TWAMM ([DCA orders](../user-guides/dollar-cost-average-orders.md)), limit orders, MEV capture, and [Ve33](../user-guides/ve33.md) token-governed liquidity.
