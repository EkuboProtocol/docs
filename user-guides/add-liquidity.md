---
description: How to become a liquidity provider on Ekubo
---

# Add liquidity

To add liquidity to Ekubo and start earning fees from user swaps, you must [create a position](https://ekubo.org/evm/positions/new).

{% hint style="info" %}
Bookmark the app and beware of signing transactions from other websites claiming to be Ekubo that are not hosted on ekubo.org. [Read more](https://en.wikipedia.org/wiki/Phishing) about phishing scams.
{% endhint %}

Adding liquidity takes three steps:

* Selecting a pool
* Selecting a price range
* Specifying an amount

### Selecting a pool

Every position is tied to a specific pool, and a pool is a combination of token pair, fee, tick spacing, and extension.

The two tokens you select — the "pair" — are the market you want to make. To market-make ETH against dollars, for example, choose ETH as the base token and USDC or DAI as the quote token. Here, the quote token is the numerator of the prices shown on the following pages. Swapping which token is which does not change the pair; it only changes how prices are displayed.

The fee you select is how much swappers are charged to trade against your liquidity. A fixed protocol fee is deducted from the swap fees you collect (currently 20% on Starknet and 10% on EVM chains, applied by the Positions contract when fees are collected) — there is no fee on your principal when you withdraw liquidity.

Tick spacing should typically be about twice the fee. It determines how narrow your price range can be, and therefore how much leverage you can take.

### Selecting a price range

Once you've selected a pool, you must select the range of prices in which you would like to market make. If the price leaves this selected price range, your position will become "out of range," meaning it is no longer actively earning fees. If the market price reaches the upper boundary, your position will hold entirely the quote token; at the lower boundary, entirely the base token.

You should choose your price range to maximize capital efficiency: a narrower range earns more fees per dollar of principal while the price stays inside it, but requires more active management.

### Specifying an amount

Once you choose the parameters of your position, all that is left is to decide how much capital you wish to deposit. Enter an amount within your balance and confirm to create the position.

You are now an Ekubo liquidity provider.
