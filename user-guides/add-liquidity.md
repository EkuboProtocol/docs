---
description: How to become a liquidity provider on Ekubo
---

# Add liquidity

To add liquidity to Ekubo, you must [create a position](https://app.ekubo.org/positions/new) using our interface hosted at [app.ekubo.org](https://app.ekubo.org).

{% hint style="info" %}
Bookmark the app and beware of signing transactions from other websites claiming to be Ekubo that are not hosted on ekubo.org. [Read more](https://en.wikipedia.org/wiki/Phishing) about phishing scams.
{% endhint %}

Adding liquidity is broken up into three steps.

* Selecting a pool
* Selecting a price range
* Specifying an amount

### Selecting a pool

Any position you create is tied to a specific pool. Pools are a combination of token pair and fee.

The 2 tokens you select, also known as the "pair," is the market you wish to make. For example, if you want to market-make ETH to dollars, you can choose ETH as the base token and USDC or DAI as the quote token. In this context, quote token means the numerator of the prices you'll see in the following pages. You can swap the two tokens, but it still refers to the same pair--it's only used for price display.

The fee you select is how much swappers are charged to trade against your liquidity, as well as how much you pay on your principal to withdraw your liquidity.

Tick spacing typically should be set to about twice the fee. Tick spacing will affect how small your price range can be, i.e. how much leverage you can get.

#### Withdrawal fee

The pool fee should be carefully selected, as it is exactly equal to the fee you pay on withdrawal of your principal. For example, consider the following scenario:

* You deposit 1000 USDC and 1 ETH into a 5 bips pool
* Several trades happen and you now have 1050 USDC and \~0.952 ETH
  * You have also earned 20 USDC in fees and 0.005 ETH in fees
* You withdraw your liquidity

You will pay a `1000 USDC * 5 bips = 0.5 USDC` and `~0.952 ETH * 5 bips = 0.000476 ETH` fee to withdraw your liquidity. You can think of the withdrawal fee as paying a swap fee for the incidental benefit of rebalancing your liquidity.

### Selecting a price range

Once you've selected a pool, you must select the range of prices in which you would like to market make. If the price leaves this selected price range, your position will become "out of range," meaning it is no longer actively earning fees. If the market price reaches the upper price boundary, you will hold entirely the quote token, and at the lower price the base token.

You should choose your price range to maximize capital efficiency while also limiting the expected number of withdrawals, since each withdrawal incurs a fee on principal.

### Specifying an amount

Once you choose the parameters of your position, all that is left is to decide how much capital you wish to deposit. Enter an amount less than your balance at this step, and click add liquidity to create your position.&#x20;

Congratulations on becoming an Ekubo liquidity provider!
