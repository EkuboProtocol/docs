---
description: How to stake, delegate, propose, and vote in Ekubo governance
---

# Participate in governance

This guide covers the practical steps. For how the system is designed — what governance controls, the contracts involved, and Ekubo, Inc.'s role — see [Governance](../products/governance.md).

## 1. Stake and delegate

Voting power comes from staked [EKUBO](ekubo-token.md), delegated to an address. Delegate to yourself to vote directly, or to someone else to have them vote on your behalf.

Use the [Delegate page](https://ekubo.org/governance/simple-delegate) in the app, or call the Staker contract directly:

| Function | Effect |
| --- | --- |
| `stake(delegate)` | Stakes your full approved balance to a delegate |
| `stake_amount(delegate, amount)` | Stakes a specific amount |
| `withdraw(delegate, recipient)` / `withdraw_amount(delegate, recipient, amount)` | Withdraws staked tokens |

There is **no lockup and no penalty** for withdrawing at any time.

{% hint style="info" %}
Your voting weight is not your staked balance. It is the *average* amount delegated to you over the voting weight smoothing duration ending when voting opens — currently 1 day. Because the voting start delay is only 1 hour, stake well before a proposal you care about is created, not after.
{% endhint %}

## 2. Create a proposal

You need voting weight at or above the proposal creation threshold (currently 100,000 EKUBO) and no other active proposal of your own.

Create one from the [proposal page](https://ekubo.org/governance/create-proposal), or on-chain:

* `propose(calls)` — submit the calls the proposal will execute
* `describe(proposalId, description)` — attach a description
* `propose_and_describe(calls, description)` — both at once

A proposal commits to its calls by hash. The **same calls must be supplied again at execution**, so keep them.

Voting opens after the voting start delay (currently 1 hour). Discuss proposals in the [Discord](https://discord.ekubo.org) before submitting — the delay exists so problems can be caught early.

## 3. Vote

Call `vote(proposalId, yea)` with `true` for yea or `false` for nay, or vote in the app. One vote per address, only during the voting period (currently 4 days).

A proposal passes if it reaches quorum (currently 3,250,000 EKUBO in yea votes) **and** receives strictly more yea than nay. A tie fails.

## 4. Cancel, if needed

`cancel(proposalId)` — available to the proposer only, and only before voting opens. This is the correction window for a mistake in a submitted proposal.

## 5. Execute

After a proposal passes and the execution delay elapses (currently 1 hour), anyone can call `execute(proposalId, calls)` with the original calls. Execution must happen within the execution window (currently 30 days) or the proposal expires.

Execution is atomic: all calls succeed or none do. A proposal that reverts can be retried within the window.

---

Current parameter values and what governance controls are documented in [Governance](../products/governance.md#proposal-lifecycle). Contract addresses are in the [governance contracts reference](../reference/contracts/governance.md).
