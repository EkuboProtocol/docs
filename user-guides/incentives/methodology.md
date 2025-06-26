---
description: How incentives are distributed for Ekubo Protocol liquidity providers
hidden: true
---

# Methodology

### Rationale

Our incentive algorithm is designed to maximize fairness of distribution. It rewards all pools for a given token pair, depending on the pair's `volatility` parameter. Instead of rewards being distributed based on fees, which are easily gamed, or based on time-weighted liquidity (a la [Uniswap V3 staker](https://github.com/Uniswap/v3-staker) or [Merkl](https://merkl.xyz/)), or some combination of the two, we use each position's contribution to the market depth for a pair.

Specifically, we compute for each position a time-weighted **market depth score**. This score is a rough estimate of the position's contribution to the market depth over a given period of time. A position earns rewards in proportion to its contribution to the total time weighted market depth score for the pair.

We re-use this methodology across all incentive campaigns, including [Starknet DeFi Spring](starknet-defi-spring.md) and Ekubo DAO Wave Zero Incentives. This infrastructure is available to others who wish to create a campaign--if you would like to do so, please reach out in the [Discord](https://discord.ekubo.org/) to get started.

Steps

Incentive tokens are first split between the two tokens in the pair. They can be evenly split, or they can be weighted towards one token or the other. This is at the discretion of the campaign administrator.

Then, we compute the hourly VWAP for the pair. We use swap events on the pool to determine the VWAP over each hour in which incentives are distributed.

Liquidity providers for a specific pair earn a share of incentives equal to their proportion of the total Market Depth Score (MDS). The MDS is computed from the a position's contribution to market depth around the current price of the pool. To compute the market depth score, we look at how much of the position's liquidity is within many bands of the current price, and add up the score.

In layman's terms: in order for your position to earn rewards, it must be placed near to the current price, where "near" is defined by the pair's volatility for that day. The more likely your liquidity is to be used, the more incentives you will earn.

The fee of the pool is also incorporated into the calculation of MDS by ignoring liquidity within `+/- 4x fee` of the current price.

To see the list of eligible pairs, visit the [rewards page](https://app.ekubo.org/defi-spring) of the app.

### How do I maximize STRK incentives?

Keep in mind the following guidelines for receiving the most STRK, in order of importance. The exact algorithm is subject to change from fortnight to fortnight.

* Larger positions earn a larger share of the total incentives
* The closer your liquidity is to the current price, the more rewards it earns
  * "Closeness" is determined by the realized volatility of the pair&#x20;
* Higher fee pools will receive a smaller share of incentives
