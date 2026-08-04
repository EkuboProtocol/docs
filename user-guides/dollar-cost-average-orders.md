---
description: >-
  Also known as TWAMM. Place orders that execute over time to enter and exit
  positions more efficiently or even programmatically
---

# Dollar-cost average orders

TWAMM, or "time-weighted average market maker," is an Ekubo extension that powers the "DCA orders" and "DCA-enabled pools" features in the [interface](https://app.ekubo.org). DCA orders are orders to sell a token at a specified rate between a start and end time. The mechanism involved in executing Ekubo's DCA orders is best described by [Paradigm](https://www.paradigm.xyz/2021/07/twamm).

DCA-enabled pools are liquidity pools that use the extension to support these orders by providing liquidity for the buy/sell side when DCA orders are imbalanced. In practice, orders are split into per-second pieces and netted against each other; whenever the ratio of buy to sell orders does not exactly match the current pool price, the difference is swapped against the pool. That ratio rarely matches the pool price exactly, which is why this liquidity is necessary for DCA orders to price well.

{% hint style="info" %}
In practice, execution of orders happens up to once per block. On Starknet, blocks are created once every few seconds, so DCA orders are best suited for trades that happen over longer time periods. As block times decrease, orders will be split into more pieces and thus orders can be placed with greater size or shorter duration given the same amount of liquidity.
{% endhint %}

Orders on both sides of a DCA-enabled pool are netted against each other, and the difference is swapped on the pool to compute the resulting price for the orders.

Ekubo's TWAMM implementation is integrated into the core protocol via [extensions](../concepts/extensions.md). There are two features in the user interface:

* **DCA-enabled pools:** liquidity pools that use the TWAMM extension
  * Provide liquidity to these pools to earn fees from DCA orders as well as regular swap volume
  * Concentrated liquidity is not supported for these pools
* **DCA orders:** orders that sell a token over a specified period for a specific pool
  * Because the price is not known at the time of the swap, "exact output" swaps are not supported
  * There is no price protection, but you may stop an order at any time
  * Arbitrage keeps pricing efficient

Because TWAMM pools are cheaply aggregated with other pools in Ekubo, and opposite orders are netted against each other, DCA orders provide efficient pricing and lower fees for large swaps, i.e. you are likely to receive the time-weighted average price of the pair on your order.

Consider using TWAMM in the following cases:

* When moving large amounts of capital into and out of positions where the order books are thin
* When converting tokens programmatically
* When you want to buy/sell a token but don't want to time the entry/exit

Note that the price you receive on your DCA orders is heavily dependent on the liquidity in the pools and other orders on the pool over the period that the order executes. If you want to ensure good execution, it's best to supply liquidity to the pool on which you want to place the order to limit the price impact of each swap.

### Creating DCA orders

The ability to place DCA orders is available in the interface [here](https://app.ekubo.org/evm/dca).

DCA orders pay fees when the orders are imbalanced: you pay swap fees to liquidity providers of the pool on which you placed the order to swap your tokens, depending on how one-sided the orders are. Volume that nets directly against opposing orders pays no swap fee. Stopping or decreasing an order is free.

{% hint style="info" %}
The contracts allow durations between `1` second and `2**32` seconds, but the specified start and end time for an order must follow specific rules to be valid.
{% endhint %}

### Adding liquidity to DCA pools

Creating a DCA-enabled pool for a pair provides the backstop liquidity that orders on that pair execute against, and that liquidity has exclusive rights to the pair's TWAMM volume. Orders cannot be placed between two tokens until at least one direct DCA-enabled pool exists.

Splitting an order into per-second pieces minimizes its price impact. You only specify an amount; Ekubo finds the best pools to split it across, just as it does for an ordinary swap. Your order is also netted against volume flowing the other way, and any volume that never reaches the backstop pool pays no fee at all. Placing an order mints an NFT representing your ownership of it.

{% hint style="warning" %}
As with the NFT you receive when you create a position, you should **never sell this NFT** — selling it gives up the right to the capital behind the order.
{% endhint %}

### Fees

All fees from the DCA orders are directed towards liquidity providers of the pool on which the order is placed.

DCA orders incur _fees_ only when there is no volume on the other side of the trade and the order must be executed against the liquidity pool. The fees paid to liquidity providers when orders are executed against the pool are like regular swap fees. Order volume that nets against opposing orders pays no fee, and stopping an order early is free.
