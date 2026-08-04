---
description: >-
  Pool types, fees, and the extensions that change what providing liquidity on
  Ekubo looks like
---

# Providing liquidity

Liquidity on Ekubo lives in one Core contract, but the shape it takes is configurable. A pool's type, its fee, and its [extension](../concepts/extensions.md) are all part of its identity, chosen when the pool is created.

For the step-by-step version in the app, see [Add liquidity](../user-guides/add-liquidity.md).

## Pool types

| Type | Liquidity shape | Suits |
| --- | --- | --- |
| **Concentrated** | Provider-chosen price range, with tick spacing controlling how narrow ranges can be | Most pairs; precise control over where capital sits |
| **Stableswap** | Concentrated around a configurable center price, with an amplification factor | Correlated assets that trade near a fixed ratio |
| **Full range** | The entire price range | Long-tail pairs and the simplest possible position |

All three settle in the same Core contract and are quoted and routed together, so choosing one does not fragment your liquidity away from the others.

Ekubo's ticks are 1/100th of a basis point — 100x finer than most concentrated-liquidity AMMs — so a range can be drawn exactly where you want it. See [Pool math](../reference/pool-math.md) for how positions and prices are represented.

## Fees

The pool fee is what swappers pay to trade against your liquidity, and it is chosen when the pool is created rather than from a fixed set of tiers. A protocol fee is applied to the swap fees you collect (10% on EVM, 20% on Starknet, both applied by the Positions contract) and funds the DAO through [revenue buybacks](governance.md#revenue-buybacks). The canonical Positions deployment charges **no fee on your principal** when you withdraw — the contract supports a withdrawal fee, but it is configured to zero.

Because any licensee can deploy their own Positions contract with its own fee settings, always check the deployment you are actually using.

Core itself charges nothing — see [Protocol architecture](../concepts/architecture.md).

## Extensions that change the LP experience

Extensions attach behavior to a pool without moving liquidity out of Core:

* **TWAMM** — pools that back [DCA orders](../user-guides/dollar-cost-average-orders.md). Providing liquidity here earns fees from order flow that executes against the pool when buy and sell orders are imbalanced, in addition to ordinary swap volume.
* **MEV capture** — charges extra on price-moving swaps and returns that value to LPs instead of searchers.
* **Boosted fees** — lets anyone fund additional fee rewards for a pool's LPs, on top of swap fees. Used for targeted liquidity campaigns.
* **[Ve33](ve33.md)** — replaces swap-fee income with emissions of a stake token, with voters directing where those emissions go and setting each pool's fee. LPs earn emissions; voters earn the swap fees.
* **Oracle** — records price history for a pair. Oracle pools are full-range and fee-free by design.

## Positions are NFTs

A liquidity position is an ERC-721 token minted by the Positions contract, so it can be held, transferred, or used as collateral like any other NFT. Its `tokenURI` resolves to the [Ekubo API](../reference/ekubo-api/README.md), which serves the position's metadata and a rendered SVG image.

{% hint style="warning" %}
Never sell the NFT representing a position or an order — it *is* the claim on the underlying capital.
{% endhint %}

## Rewards beyond swap fees

Liquidity can also earn from [incentive campaigns](rewards.md), which measure the depth your position provides near the market price and distribute reward tokens through periodic drops.

## Risk

Providing liquidity is not a yield product. A position earns fees from the volume that trades against it, and simultaneously accrues divergence loss as the price moves — ending up holding more of whichever asset fell in relative value. Narrowing a range concentrates both effects at once: more fees per dollar while the price is in range, and faster conversion into the losing asset when it moves. Whether a position is profitable depends on the volume it captures relative to that divergence, which is a property of the market, not of the protocol.
