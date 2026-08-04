---
description: Customize pool behavior by writing extension contracts
---

# 🔌 Extensions

Extensions allow you to insert custom logic at certain pool lifecycle events. Extensions can also re-enter core contracts (as can any other contract) in order to place their own swaps, updates, etc. before or after the external contract interacts with a pool. This enables third party developers to leverage the efficient and secure core AMM protocol of Ekubo, including concentrated liquidity, without implementing any of the maths. With this simple interface, you can build oracles, new order types, trading strategies, privacy solutions: you're limited only to your own imagination!

{% hint style="info" %}
Each pool has its own separate state, meaning the capital deposited into each pool with an extension is isolated from all other pools, including other pools with the same extension.
{% endhint %}

### Rationale

Liquidity fragmentation is inevitable. In the absence of extensions, others will make small improvements to the Ekubo design or add new features, and deploy a variant of the core AMM. As a result, users must split their trades across many different sources of liquidity.

Ekubo aims to solve this problem by reducing the cost of fragmentation to near-zero. This is the purpose of the singleton design and the till pattern. Ekubo is a platform for an ecosystem of different types of pools that are all aggregated with every aggregator and arbitrageur, so markets can operate as efficiently as possible. This ecosystem of different kinds of liquidity also has the benefit of providing traders the best possible execution.

### Flexibility

Extensions are useful for using Ekubo in interesting ways. But you might want to use a completely different algorithm for trading, perhaps use a different curve. Don't fret: you can build pretty much any curve just by overlapping several `x*y=k` positions, which means Ekubo's core components can be used for many different AMM use cases. In the extreme case where you want to quote each trade individually, you can use Ekubo as an order book with its extremely small ticks by just placing one-tick orders at the prices your extension determines, e.g. from an oracle or based on time.

Because an extension can re-enter the core Ekubo contract to perform its own actions within these lifecycle events, the simple interface allows for a huge amount of customization of pool behavior. For example, you could front-run a swap by adding your own liquidity, providing price improvement; or you could read the pool price at the beginning of the block to provide an oracle.

### Immutability

Extensions are specified as part of the pool key. The specified extension is an immutable configuration of a pool. Before a pool can be initialized with an extension, the extension must be registered with Core along with the set of pool lifecycle events ("call points") at which it should be called.

{% hint style="info" %}
The set of "call points" never changes for the pool, so you should specify all the places you might need to respond to pool actions. How call points are declared differs by deployment: on Starknet, the extension registers them with Core via `set_call_points`; on EVM (V3), the call points are encoded in the top byte of the extension's own address — extension addresses are mined so the address itself declares the hooks.
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

Because extensions can have their own state like any other contract, you can use your own contract state to implement new kinds of orders. For example, limit orders can be created by:

* Add functions that allow users to create limit orders via your extension
* Immediately add liquidity to the pool for new limit orders
* After swaps, remove any limit orders from the pool that were fully executed

{% hint style="info" %}
Extensions are immutable for a pool, so you must either make them upgradeable, or make them so simple they never need to be upgraded. We recommend making extensions immutable and deploying new versions when necessary.
{% endhint %}

Examples of extensions can be found [here (EVM)](https://github.com/EkuboProtocol/evm-contracts/tree/main/src/extensions) or [here (Starknet)](https://github.com/EkuboProtocol/starknet-contracts/tree/main/src/extensions)
