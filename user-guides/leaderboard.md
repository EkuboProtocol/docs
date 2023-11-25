---
description: Understanding the leaderboard
---

# Leaderboard

### Purpose

The leaderboard is the way for users to understand how the Ekubo development team views the impact of their liquidity on the protocol. Currently it is based on how many fees they've earned, converted to ETH. We chose this metric to start for a couple of reasons:

* It is difficult to farm and it cannot be sybil attacked
* The points scale with the amount of risk taken in providing liquidity
* The points scale with the usefulness to traders

We will tweak and improve this algorithm, but we published it early so users could understand their placement among each other, as well as give feedback on the mechanism.

### Referral points

You can earn points by referring other users to Ekubo. To do so, connect a wallet, go to the new position page, select some good parameters and then click the referral link button on the top right to copy your referral link.

Whenever someone creates a position using your referral link, your address will be linked to the position and you will earn 20% of the points they earn from their own position. The user of the referral link still earns 100% of their points.

### FAQ

<details>

<summary>How are points calculated?</summary>

Currently we aggregate the fee collection events emitted from the Ekubo smart contracts, and then convert to ETH at the current price of each of the 2 tokens.

When we decide to utilize the points in any other mechanism, we will make sure to include uncollected fees in our calculations.

</details>

<details>

<summary>Why did my points go down?</summary>

Because the number of points is calculated based on the value of the fees earned in ETH, it will also fluctuate with the price of ETH. ETH fees earned, on the other hand, do not fluctuate in value.

Note that the absolute number of points does not matter, rather it is the quantity of points relative to your peers.

</details>

<details>

<summary>I don't see my points</summary>

Points are not accumulated until you withdraw your fees. This is due to a technical limitation.

But don't waste gas just to withdraw fees. When we compute your points for other purposes, we will include uncollected fees too.

</details>

<details>

<summary>How will my points be used? Will there be any reward for points?</summary>

We have not announced any plans to use points for anything.

</details>
