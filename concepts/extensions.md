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

### What belongs in an extension

Extensibility is for creating new *pool functionality*: behavior that plugs into the [flash accounting system](architecture.md#flash-accounting) and works as if it had been part of the original design. A TWAMM pool, an oracle pool, a vote-governed ve(3,3) pool — each changes what a pool *is*, and every router, aggregator, and arbitrageur settles against it through the same lock as any other pool.

What an extension is not is a place to add third-party dependencies. An extension is an immutable part of its pools' keys and sits in the hot path of every interaction with them, so coupling one to an external protocol welds that protocol's risks, upgrades, and failure modes into the pool itself — permanently, for every LP and trader in it.

The line is easy to draw in practice. Take a product someone might plausibly want to build. A position spanning a few basis points around the current price offers the same depth *at* that price as a far larger wide-range position, so the capital the wide position would have tied up is not needed in the pool at all. The product keeps a narrow position centered on the market, parks the capital it frees in a money market, and moves funds between the two as the price drifts — drawing on the money market to re-center or top up the position, returning what the position no longer needs. Nothing in that changes how the pool works. Swaps quote, fill, and settle exactly as before, and from the pool's point of view the whole arrangement is indistinguishable from an LP who mints and burns positions by hand. What it decides is *where capital sits and when it moves*: that is a **strategy**, and it belongs on top of the AMM, not inside it.

On top is also where an idea like this can be judged and adjusted. A narrower range concentrates fee income and divergence loss in equal measure, the price leaves it more often, and every re-centering pays gas and swap fees — so whether the arrangement beats simply holding a wider position depends on volatility, gas prices, and money-market rates, and the answer moves as they do. A strategy on top can be re-tuned, or abandoned, in the next block. An extension cannot: it is fixed in the pool key, so every revision is a new pool that must attract liquidity from scratch, and until then one particular money market sits in the hot path of every swap for everyone in the pool, LPs and traders alike, whether they want that exposure or not.

There are many ways to run a strategy on top. Vaults in the style of Yearn run them autonomously as contract code, at the cost of a newly audited contract per strategy. Hedge funds run them with people, who take a share of the profits and make mistakes. The most forward-looking way is to hand the strategy to an AI agent and let it run autonomously — which is precisely what the [MCP server](../products/mcp-server.md) is for: an agent gets the same tokens, quotes, position data, and execution plans the interface uses, so the strategy lives in the agent's instructions, where rewriting it costs a sentence, rather than in anyone's pool.

### Flexibility

You may want a different trading algorithm entirely — a different curve. You can approximate almost any curve by overlapping several `x*y=k` positions, so Ekubo's core components serve a wide range of AMM designs. At the extreme, where you want to quote every trade individually, Ekubo's very small ticks let you use it as an order book: place one-tick orders at whatever prices your extension decides, whether from an oracle or as a function of time.

Because an extension can re-enter the core Ekubo contract to perform its own actions within these lifecycle events, the simple interface allows for a huge amount of customization of pool behavior. For example, on the before-swap call point you could add your own liquidity ahead of the trade, improving the price the swapper gets; or you could record the pool's price *before* the trade moves it, which is exactly how the Oracle extension builds its history — it snapshots on before-swap and before-position-update, so every observation is a pre-trade price.

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

Source code: [EVM extensions](https://github.com/EkuboProtocol/evm-contracts/tree/v3.2.0/src/extensions) and [Starknet extensions](https://github.com/EkuboProtocol/starknet-contracts/tree/v5.0.3/src/extensions).

For how this design compares to Uniswap v4 hooks — and why the `forward` primitive replaces v4's custom-accounting machinery — see [Extensions vs. Uniswap v4 hooks](extensions-vs-v4-hooks.md).
