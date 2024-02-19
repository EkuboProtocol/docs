---
description: Distributing STRK incentives to users of Ekubo protocol
---

# Starknet DeFi Spring

### Introduction

Starknet Foundation is distributing STRK rewards to users of Ekubo Protocol as part of the [Starknet DeFi Spring](http://defispring.starknet.io/). Our methodology for the allocation, subject to change, is described below.

### Incentive allocation methodology

{% hint style="warning" %}
This section is currently under development. As with the leaderboard, we encourage you to optimize your activity for profitability, rather than rewards.
{% endhint %}

We will define allocation to users based on the same measures that are used to determine protocol-level allocations, so that users responsible for Ekubo's incentive allocation receive all of the incentives.

We will split the allocation by pair, and reward all active liquidity providers equally for each second they provide liquidity in the pair.

The following pairs are eligible for rewards:

* [STRK/USDC](https://app.ekubo.org/charts/STRK/USDC)
* [STRK/ETH](https://app.ekubo.org/charts/STRK/ETH)
* [ETH/USDC](https://app.ekubo.org/charts/ETH/USDC)
* [USDC/USDT](https://app.ekubo.org/charts/USDC/USDT)

The query we use to determine allocation will be published for review to the [indexer](https://github.com/ekuboprotocol/indexer) repository when ready.

### How do I earn the most STRK incentives?

Keep in mind the following guidelines for receiving the most STRK. The exact algorithm is subject to change from fortnight to fortnight.

* Higher fee pairs will receive fewer rewards per liquidity
* The more capital efficient your position, the greater your rewards
* The longer your position stays active, the greater your rewards
* STRK rewards will be directed towards the most volatile pairs

### Participation in the program

Because we compute rewards off-chain and retroactively, no special action is required to participate in this program.

However, to be eligible for rewards, **you must provide active liquidity in one of the eligible pairs**.

Team members, investors, and partners will not be eligible to receive rewards from this allocation.

### Claiming your allocation

Within the next few weeks, we will provide a user interface within the [Ekubo Interface](https://app.ekubo.org) to interact with the autonomous STRK distribution smart contracts. There will be no deadline to claim these retroactive allocations.

The first allocation will be available to claim the week of March 4th.
