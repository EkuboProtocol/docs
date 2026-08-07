---
description: >-
  Also known as TWAMM. Place orders that execute over time to enter and exit
  positions more efficiently or even programmatically
---

# Dollar-cost average orders

TWAMM, or "time-weighted average market maker," is an Ekubo extension that powers the "DCA orders" and "DCA-enabled pools" features in the [interface](https://ekubo.org). DCA orders are orders to sell a token at a specified rate between a start and end time. The mechanism involved in executing Ekubo's DCA orders is best described by [Paradigm](https://www.paradigm.xyz/2021/07/twamm).

DCA-enabled pools are liquidity pools that use the extension to support these orders by providing liquidity for the buy/sell side when DCA orders are imbalanced. In practice, orders are split into per-second pieces and netted against each other; whenever the ratio of buy to sell orders does not exactly match the current pool price, the difference is swapped against the pool. That ratio rarely matches the pool price exactly, which is why this liquidity is necessary for DCA orders to price well.

{% hint style="info" %}
In practice, virtual orders execute at most once per block. DCA orders are therefore best suited to trades that play out over longer periods than the chain's block time. The shorter the block time, the more pieces an order is split into, so the same liquidity supports larger or shorter-duration orders.
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

You can place DCA orders in the [interface](https://ekubo.org/dca).

DCA orders pay fees when the orders are imbalanced: you pay swap fees to liquidity providers of the pool on which you placed the order to swap your tokens, depending on how one-sided the orders are. Volume that nets directly against opposing orders pays no swap fee. Stopping or decreasing an order is free.

{% hint style="info" %}
An order's start and end times must each be a multiple of a step size that grows the further in the future they are. The smallest step is 256 seconds on EVM chains (16 on Starknet), so the shortest possible order is 256 seconds; the longest is just under `2**32` seconds.
{% endhint %}

### Adding liquidity to DCA pools

Creating a DCA-enabled pool provides the backstop liquidity that orders on it execute against, and that liquidity has exclusive rights to that pool's TWAMM volume. Orders cannot be placed between two tokens until at least one direct DCA-enabled pool exists.

Splitting an order into per-second pieces minimizes its price impact. You choose the DCA-enabled pool the order runs against and specify an amount; the order is then netted against volume flowing the other way, and any volume that never reaches the backstop pool pays no fee at all. Placing an order mints an NFT representing your ownership of it.

{% hint style="warning" %}
As with the NFT you receive when you create a position, you should **never sell this NFT** — selling it gives up the right to the capital behind the order.
{% endhint %}

### Fees

All fees from the DCA orders are directed towards liquidity providers of the pool on which the order is placed.

DCA orders incur _fees_ only when there is no volume on the other side of the trade and the order must be executed against the liquidity pool. The fees paid to liquidity providers when orders are executed against the pool are like regular swap fees. Order volume that nets against opposing orders pays no fee, and stopping an order early is free.
