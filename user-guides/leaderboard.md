---
description: Understanding the leaderboard
---

# 🏆 Leaderboard

{% hint style="info" %}
The source code for the leaderboard is available in the [indexer](https://github.com/EkuboProtocol/indexer/blob/7bfd8ff38a03d0e7f469e20a9f84a5e9d64ef8c4/src/dao.ts#L982) repository.
{% endhint %}

## Purpose

The leaderboard is enables users to understand how the Ekubo development team _currently_ views the impact of their past participation in Ekubo protocol.

{% hint style="warning" %}
_**We may change the rules of the leaderboard at any time, including retroactively**_. This early version is made available in order to guide users towards being productive liquidity providers.
{% endhint %}

### **Factors**

#### **Fees earned by a position**

This is the biggest component of a user's points. It is affected by both the [time based multiplier](leaderboard.md#time-based-multiplier) and the [pool popularity multiplier](leaderboard.md#pool-popularity-multiplier), and the combination is multiplicative.

We chose this to be the primary component of points earned for the following reasons:

* It is difficult to farm
* The points scale with the amount of risk taken in providing liquidity
  * Higher risk pairs typically charge higher fees
* The points scale with the usefulness to traders
  * Users will pay more fees for useful liquidity
  * Lower fee pools will get more trades, and have a higher multiplier

#### Withdrawal protocol fees

Fees paid to the protocol on withdrawal are counted using only the time-based multiplier.

#### Base points for each position minted

You will earn `2,000` base points for each position minted.

* This covers the gas paid for minting and withdrawing a position
* The position must be in-range to earn the base points, i.e. limit orders are not counted

### Multipliers

#### Pool popularity multiplier

A pool's popularity is measured by the number of all-time swaps against the pool, resulting in a multiplier up to 10x. The formula is modeled in [here](https://www.desmos.com/calculator/v2l56yxgd9).

In addition, a recent query of each pool's multiplier can be found [here](https://gist.github.com/moodysalem/b0741fedb8eef6776b6c51ac77526207#file-result-csv).

#### High pool fee adjustment factor

To avoid users effectively buying points via withdrawal fees, and thus further reward organic activity on the protocol, there is an adjustment factor that reduces the amount of points earned based on the pool fee. The points earned by a position are multiplied by `1 - sqrt(fee)`.&#x20;

For an example, a pool with a 100% fee cannot earn any points, since the pool cannot be traded against.

#### Time-based multiplier

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

### Referral points

You can earn points by referring other users to Ekubo. You may copy your referral link from the [leaderboard](https://app.ekubo.org/leaderboard) page.

Whenever someone creates a position using your referral link, your address will be linked to the position and you will earn **20%** of the points they earn from their own position. The user of the referral link still earns **100%** of their points.

### FAQ

<details>

<summary>How do I earn the most points?</summary>

The primary metric that contributes to points is fees earned. Collect fees by providing liquidity on the most popular pools to earn the most points.

</details>

<details>

<summary>Why did my points go down?</summary>

We may adjust the algorithm at any point, including retroactively. Keep in mind, points are a relative scale--the absolute number does not matter.

</details>

<details>

<summary>Where are my points?</summary>

The leaderboard is recalculated a few times per day. If you don't see your points, check back the following day.

</details>

<details>

<summary>How will my points be used / Will there be any reward for points?</summary>

We have not announced any plans to use points for anything.

</details>
