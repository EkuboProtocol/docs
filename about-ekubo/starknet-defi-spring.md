---
description: Incentives for Ekubo Protocol liquidity providers
---

# 🌻 Starknet DeFi Spring

### Introduction

Users of Ekubo protocol are receiving STRK rewards as part of the [Starknet DeFi Spring](http://intract.io/starknet) by the Starknet Foundation. Our methodology for generating the suggested allocation of these incentives to Ekubo users is described below.

### Methodology

We suggest allocation to users based on the same measures that are used to determine protocol-level allocations, so that the same users responsible for Ekubo's portion of the total incentive allocation also receive all of the incentives.

The first split of the allocation is per-pair. The foundation assigns Ekubo protocol allocations of STRK incentives for a list of pairs, based on Ekubo protocol's share of the total market depth for that pair, i.e. its market depth score. The market depth score is computed from the time-weighted market depth around the current price of the pool, where the exact depth measured is determined by the 30-day realized volatility for the pair.

Within a specific pair, we allocate to liquidity providers based on the amount of principal they have within a specific range of the current price, determined by the 14-day realized volatility of the pair (we use a tighter range than the foundation in order to incentivize active liquidity providers.) In order for your position to earn rewards, it must be placed near to the current price.

The pool fee is deducted from the market depth score of a position.

To see the list of eligible pairs, visit the [rewards page](https://app.ekubo.org/defi-spring) of the app.

### How do I maximize STRK incentives?

Keep in mind the following guidelines for receiving the most STRK, in order of importance. The exact algorithm is subject to change from fortnight to fortnight.

* Larger positions earn more incentives
* The closer your liquidity is to the current price, the more rewards it earns
  * This is based on the 14-day realized volatility of the pair&#x20;
* Higher fee pools will receive slightly less incentives

### Participation in the program

Because we compute the suggested allocation of rewards off-chain and retroactively, no action is required to participate in this program. If you have an active position on one of the eligible pairs, you will receive rewards that can be claimed at the end of each period.

### Claiming your allocation

You can claim your allocation on the [rewards page](https://app.ekubo.org/defi-spring) of the app.

{% hint style="info" %}
If you need to send a claim manually to the airdrop contract, the proof data is made available in [this repository](https://github.com/EkuboProtocol/strk-defi-spring-proof-data).
{% endhint %}
