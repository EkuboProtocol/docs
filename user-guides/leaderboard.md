---
description: Understanding the leaderboard
---

# Leaderboard

{% hint style="info" %}
The source code for the leaderboard is available in the [indexer](https://github.com/EkuboProtocol/indexer/blob/7bfd8ff38a03d0e7f469e20a9f84a5e9d64ef8c4/src/dao.ts#L982) repository.
{% endhint %}

### Purpose

The leaderboard is the way for users to understand how the Ekubo development team views the impact of their participation in Ekubo protocol. We advise that you prioritize effective usage of the protocol to earn the greatest number of points.

{% hint style="warning" %}
We reserve the right to change the rules of the leaderboard at any time. We've published this early version so users can understand what activity is most valued by the protocol development team.
{% endhint %}

### **Factors**

#### **Fees earned by a position**

This is the biggest factor of a user's position on the leaderboard. Prioritize earning fees from real trading volume. We chose this primary factor for the following reasons:

* It is difficult to farm and it cannot be sybil attacked
* The points scale with the amount of risk taken in providing liquidity
  * Higher risk pairs typically charge higher fees
* The points scale with the usefulness to traders
  * Users will pay more fees for useful liquidity

#### Withdrawal protocol fees

Fees paid to the protocol on withdrawal are counted the same as fees earned from swapping.

#### Base points for each position minted

You will earn `2,000` base points for each position minted.

* This covers the gas paid for minting and withdrawing a position
* Small enough that you should not bother to farm this
* The position must be in-range to earn the base points, i.e. limit orders are not counted

### Multipliers

### High pool fee adjustment factor

To avoid users effectively buying points via withdrawal fees, and thus further reward organic activity on the protocol, there is an adjustment factor that reduces the amount of points earned based on the pool fee. The points earned by a position are multiplied by `1 - sqrt(fee)`.&#x20;

For an example, a pool with a 100% fee cannot earn any points, since the pool cannot be traded against.

### Pair popularity multiplier

A pair will have a multiplier on points earned from fees based on the popularity of the pool, to account for the usefulness to traders. Popularity is currently determined by the swap count. Provide liquidity on the most desirable trading pairs to earn the most points.

### Referral points

You can earn points by referring other users to Ekubo. You may copy your referral link from the [leaderboard](https://app.ekubo.org/leaderboard) page.

Whenever someone creates a position using your referral link, your address will be linked to the position and you will earn **20%** of the points they earn from their own position. The user of the referral link still earns **100%** of their points.

### Points multiplier

We chose to reward early liquidity providers with a points multiplier based on the date their position was created in the UTC timezone.

The multiplier follows the formula:

$$f(date) = 1 + 2 * e^{(date- '2023-09-14') * -0.01)}$$

Here are some example dates and their corresponding multipliers. Note, as with the rest of this algorithm, the multiplier is subject to change. We will avoid adjusting the multipliers downwards for past dates.

| Date       | Multiplier         |
| ---------- | ------------------ |
| 2023-09-14 | 3                  |
| 2023-10-14 | 2.4816364413634358 |
| 2023-11-14 | 2.0867017381489996 |
| 2023-11-27 | 1.9542278310420688 |
| 2023-12-31 | 1.6791910512898784 |
| 2024-01-31 | 1.4981506092633364 |

### FAQ

<details>

<summary>How do I earn the most points?</summary>

The primary metric that contributes to points is fees earned. Collect fees by providing liquidity on the most popular pairs to earn the most points. Make sure to keep your position active by rebalancing after large price movements.

</details>

<details>

<summary>Why did my points go down?</summary>

Because the number of points is calculated based on the value of the fees earned in ETH, it will also fluctuate with the price of ETH. ETH fees earned, on the other hand, do not fluctuate in value.

Note that the absolute number of points does not matter, rather it is the quantity of points relative to your peers.

</details>

<details>

<summary>Where are my points?</summary>

The leaderboard is recalculated at most a few times per day. If you don't see your points, check back the following day.

</details>

<details>

<summary>How will my points be used? Will there be any reward for points?</summary>

We have not announced any plans to use points for anything.

</details>
