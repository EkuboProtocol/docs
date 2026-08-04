---
description: Customize pool behavior by writing extension contracts
---

# Extensions

Extensions let you insert custom logic at defined points in a pool's lifecycle. Like any other contract, an extension can also re-enter Core to place its own swaps or position updates before or after the calling contract interacts with a pool. This lets third-party developers build on Ekubo's efficient, audited AMM — concentrated liquidity included — without reimplementing any of the math. From this small interface you can build oracles, new order types, trading strategies, and privacy solutions.

{% hint style="info" %}
Each pool has its own separate state, meaning the capital deposited into each pool with an extension is isolated from all other pools, including other pools with the same extension.
{% endhint %}

### Rationale

Liquidity fragmentation is inevitable. In the absence of extensions, others will make small improvements to the Ekubo design or add new features, and deploy a variant of the core AMM. As a result, users must split their trades across many different sources of liquidity.

Ekubo aims to solve this problem by reducing the cost of fragmentation to near-zero. This is the purpose of the [singleton design and the till pattern](architecture.md). Ekubo is a platform for an ecosystem of different types of pools that are all aggregated with every aggregator and arbitrageur, so markets can operate as efficiently as possible. This ecosystem of different kinds of liquidity also has the benefit of providing traders the best possible execution.

### Flexibility

You may want a different trading algorithm entirely — a different curve. You can approximate almost any curve by overlapping several `x*y=k` positions, so Ekubo's core components serve a wide range of AMM designs. At the extreme, where you want to quote every trade individually, Ekubo's very small ticks let you use it as an order book: place one-tick orders at whatever prices your extension decides, whether from an oracle or as a function of time.

Because an extension can re-enter the core Ekubo contract to perform its own actions within these lifecycle events, the simple interface allows for a huge amount of customization of pool behavior. For example, you could front-run a swap by adding your own liquidity, providing price improvement; or you could read the pool price at the beginning of the block to provide an oracle.

### Immutability

Extensions are specified as part of the pool key. The specified extension is an immutable configuration of a pool. Before a pool can be initialized with an extension, the extension must be registered with Core along with the set of pool lifecycle events ("call points") at which it should be called.

{% hint style="info" %}
Declare every hook you might need up front. How call points are declared — and how permanent they are — differs by deployment. On EVM (V3) they are encoded in the top byte of the extension's own address (addresses are mined so the address itself declares the hooks), and Core rejects a second registration, so they are genuinely immutable. On Starknet the extension registers them with Core via `set_call_points`, which can be called again; a change applies to all of that extension's existing pools, so treat them as immutable by convention.
{% endhint %}

The full list of call points is:

* Before pool initialization
* After pool initialization
* Before position update
* After position update
* Before collect fees
* After collect fees
* Before a swap
* After a swap

Because an extension holds its own state like any other contract, you can use that state to implement new kinds of orders. Limit orders, for example, work like this:

* Expose functions that let users create limit orders through your extension
* Immediately add liquidity to the pool for each new order
* After each swap, remove any orders that were fully executed

{% hint style="info" %}
An extension is immutable for a given pool, so either make the extension itself upgradeable or keep it simple enough that it never needs upgrading. We recommend immutable extensions, deploying a new version when one is needed.
{% endhint %}

## Available extensions

These extensions are already built and deployed. Each one is a pool type you can trade against or build on — see [Contract addresses](../reference/contracts/README.md) for deployments.

| Extension | Chains | What it does |
| --- | --- | --- |
| **Oracle** | Both | Records on-chain price history for a token against a designated quote asset — native ETH on EVM, a configured oracle token on Starknet |
| **TWAMM** | Both | Executes orders gradually over time, powering [DCA orders](../user-guides/dollar-cost-average-orders.md) |
| **Limit orders** | Starknet | Narrow positions exactly one tick spacing wide (128 ticks, about 1.28 bps) that are pulled automatically once fully executed |
| **MEV capture** | EVM | Charges additional fees on swaps that move the price significantly within a block, directing that value back to liquidity providers |
| **Boosted fees** | EVM | Streams externally funded fee rewards to a pool's liquidity providers |
| **[Ve33](../products/ve33.md)** | EVM | Token-governed liquidity: stakers vote to direct emissions and set pool fees, and earn the fees of the pools they support |
| **[Signed exclusive swaps](../integration-guides/signed-exclusive-swaps.md)** | EVM | RFQ-style pools where a controller signs each swap off-chain with its own fee and bounds |

Source code: [EVM extensions](https://github.com/EkuboProtocol/evm-contracts/tree/main/src/extensions) and [Starknet extensions](https://github.com/EkuboProtocol/starknet-contracts/tree/main/src/extensions).
