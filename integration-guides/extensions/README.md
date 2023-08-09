---
description: Customize pool behavior by writing extension contracts
---

# Extensions

## Summary

Extensions allow you to insert custom logic at certain pool lifecycle events. Extensions can also re-enter core contracts (as can any other contract) in order to place their own swaps, updates, etc. before or after the external contract interacts with a pool. This enables third party developers to leverage the efficient and secure core AMM protocol of Ekubo, including concentrated liquidity, without implementing any of the maths. With this simple interface, you can build oracles, new order types, trading strategies, privacy solutions: you're limited only to your own imagination!

### Rationale

Liquidity fragmentation is inevitable. Even if Ekubo builds the best AMM on Starknet, without extensions, others will make small improvements to the design, or add new features, and deploy their variant. As a result, users must split their trades across many different sources of liquidity.

Ekubo aims to solve this problem by reducing the cost of fragmentation to near-zero. This is the purpose of the singleton design and the till pattern. We aim to create a platform for an ecosystem of different types of pools that are all aggregated with every aggregator and arbitrageur, so markets can become as efficient as possible. This ecosystem of different kinds of liquidity also has the benefit of providing traders the best possible execution.

Because extensions are so tightly paired with the core AMM, aggregators and arbitrageurs are easily able to integrate them. But you might want to use a different strategy for trading, perhaps one that is based on time. Don't fret: you can build pretty much any curve just by overlapping several `x*y=k` positions, which means Ekubo's core components can be used for many different AMM use cases. In the extreme case where you want to quote each trade individually, you can use Ekubo as an order book with its extremely small ticks by just placing one-tick orders at the prices your extension determines, e.g. from an oracle or based on time.

Because an extension can re-enter the core Ekubo contract to perform its own actions within these lifecycle events, the simple interface allows for a huge amount of customization of pool behavior. For example, you could front-run a swap by adding your own liquidity, providing price improvement; or you could read the pool price at the beginning of the block to provide an oracle.

Extensions are specified as part of the pool key. In other words, the specified extension is an immutable configuration of a pool. When the pool is initialized, an extension is always called before the initialization, and at this point the extension can specify at what points it should be called in the future.&#x20;

{% hint style="info" %}
The set of "call points" never changes for the pool, so you should specify all the places you might need to respond to pool actions.
{% endhint %}

Because extensions can have their own state like any other contract, you can use this state to determine how to react to certain lifecycle events. For example, limit orders can be created by:

* Add functions that allow users to create limit orders via your extension
* Immediately add liquidity to the pool for new limit orders
* After swaps, remove any limit orders from the pool that were fully executed

{% hint style="info" %}
Extensions are immutable for a pool, so you must either make them upgradeable, or make them so simple they never need to be upgraded.
{% endhint %}
