---
description: Incentives for Ekubo Protocol liquidity providers
---

# 🌻 Starknet DeFi Spring

### Introduction

Users of Ekubo protocol are receiving STRK rewards as part of the [Starknet DeFi Spring](https://defispring.starknet.io/) by the Starknet Foundation. Our methodology for computing allocation of these incentives to Ekubo liquidity providers is described below.

### Rationale

We follow the methodology of the foundation's distribution as closely as possible so that any incentives allocated to Ekubo protocol go directly to the users that provided the respective liquidity.

This methodology was designed with input from Ekubo, Inc. to allocate incentives to liquidity providers that make useful contributions to the overall liquidity, i.e. liquidity that is used or likely to be used by swappers.

### Methodology

First, the foundation assigns fixed amounts of tokens to each pair that it wishes to incentivize. This is discretionary and based on the foundation's goals.

Liquidity providers for a specific pair earn a share of incentives equal to their proportion of the total Market Depth Score (MDS). The MDS is computed from the a position's contribution to market depth around the current price of the pool. We take the 1-day realized volatility for the pair on the day the incentives are earned, and measure the market depth within many multiples of this realized volatility (e.g. 0.25x, 0.5x, 1x, 2x) and assign weights to each slice based on how likely it is to be used.

In layman's terms: in order for your position to earn rewards, it must be placed near to the current price, where "near" is defined by the pair's volatility for that day. The more likely your liquidity is to be used, the more incentives you will earn.

The fee of the pool is also incorporated into the calculation of MDS by ignoring liquidity within `+/- 4x fee` of the current price.

To see the list of eligible pairs, visit the [rewards page](https://app.ekubo.org/defi-spring) of the app.

### How do I maximize STRK incentives?

Keep in mind the following guidelines for receiving the most STRK, in order of importance. The exact algorithm is subject to change from fortnight to fortnight.

* Larger positions earn a larger share of the total incentives
* The closer your liquidity is to the current price, the more rewards it earns
  * "Closeness" is determined by the realized volatility of the pair&#x20;
* Higher fee pools will receive a smaller share of incentives

### Participation in the program

Because we compute the suggested allocation of rewards off-chain and retroactively, no action is required to participate in this program. If you have an active position on one of the eligible pairs, you will receive rewards that can be claimed at the end of each period.

### Claiming your allocation

You can claim your allocation on the [rewards page](https://app.ekubo.org/defi-spring) of the app.

{% hint style="info" %}
If you need to send a claim manually to the airdrop contract, the proof data is included in the [weekly backup of our indexer database](https://github.com/EkuboProtocol/indexer/actions/workflows/backup.yml).
{% endhint %}
