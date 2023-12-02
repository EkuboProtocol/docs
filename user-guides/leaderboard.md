---
description: Understanding the leaderboard
---

# Leaderboard

### Purpose

The leaderboard is the way for users to understand how the Ekubo development team views the impact of their participation in Ekubo protocol. Currently it is based on the following, all affected by the points multiplier:

* Fees earned by a position
  * It is difficult to farm and it cannot be sybil attacked
  * The points scale with the amount of risk taken in providing liquidity
  * The points scale with the usefulness to traders
* Withdrawal protocol fees paid also earn points (see adjustment factor)
* 2k base points for each position minted
  * This covers the gas paid for minting and withdrawing a position

{% hint style="info" %}
We will tweak and improve this algorithm, but we published it early so users could understand their placement among each other, as well as give feedback on the mechanism.
{% endhint %}

### Pool fee adjustment factor

To avoid users effectively buying points via withdrawal fees, and thus further reward organic activity on the protocol, there is an adjustment factor that reduces the amount of points earned based on the pool fee. The points earned by a position are multiplied by `1 - sqrt(fee)`. For an example, a pool with a 100% fee cannot earn any points, since the pool cannot be traded against.

### Referral points

You can earn points by referring other users to Ekubo. To do so, connect a wallet, go to the new position page, select some good parameters and then click the referral link button on the top right to copy your referral link.

Whenever someone creates a position using your referral link, your address will be linked to the position and you will earn 20% of the points they earn from their own position. The user of the referral link still earns 100% of their points.

### Points multiplier

We chose to reward early liquidity providers with a points multiplier based on the date their position was created in the UTC timezone.

The multiplier follows the formula:

$$f(date) = 1 + 2 * e^{MAX((date - '2023-09-14'), 0) * -0.01)}$$

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

<summary>Why did my points go down?</summary>

Because the number of points is calculated based on the value of the fees earned in ETH, it will also fluctuate with the price of ETH. ETH fees earned, on the other hand, do not fluctuate in value.

Note that the absolute number of points does not matter, rather it is the quantity of points relative to your peers.

</details>

<details>

<summary>Where are my points?</summary>

Points are not accumulated until you withdraw your fees. **This is due to a technical limitation**.

But **don't waste gas to withdraw fees, just to collect points**. When we compute your points for other purposes, we will include uncollected fees too.\
\
Points from fees are awarded at _roughly_ 1000 points per dollar of fees earned when you withdraw. If you did not earn any fees you will not earn many points.

</details>

<details>

<summary>How will my points be used? Will there be any reward for points?</summary>

We have not announced any plans to use points for anything.

</details>
