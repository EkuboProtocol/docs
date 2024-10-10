---
description: Understand how governance of Ekubo Protocol is designed
---

# 🏩 Governance

## Introduction

This guide will help you understand how to participate in the governance of Ekubo Protocol by staking tokens, creating proposals, and voting on them.

The governance contracts are open source and permissively licensed on [GitHub](https://github.com/EkuboProtocol/governance).

### Proposal Lifecycle

#### 1. Staking Tokens

Before you can create or vote on proposals, you need to stake your tokens with the Staker contract. You can do so via the [Delegate](https://app.ekubo.org/governance/simple-delegate) page in the app. Staking tokens means you lock your tokens in the Governor contract, which gives you voting power. There is no penalty for unstaking, nor minimum amount of time that tokens can be staked.

Staking can also be done at the smart contract level. Note that voting weight is not exactly equal to staked tokens due to the `voting_weight_smoothing_period`. This is the number of seconds over which the average number of tokens delegated to you is taken, which is what determines your voting weight.

**How to Stake Tokens**

1. **Stake All Tokens**:
   * Use the `stake` function to delegate all your approved tokens to a specific address.
   * Example: `stake(delegateAddress)`
2. **Stake a Specific Amount**:
   * Use the `stake_amount` function to delegate a specified amount of tokens.
   * Example: `stake_amount(delegateAddress, amount)`

#### 2. Creating a Proposal

Once you have staked tokens, you can create a proposal. The page in the app to do so is [here](https://app.ekubo.org/governance/create-proposal). A proposal is a request to execute a specific set of calls, either to self (Governor) or other smart contracts.

Proposals can be created directly from the smart contracts as well:

**How to Create a Proposal**

1. **Propose**:
   * Use the `propose` function to submit your proposal along with the actions you want to execute.
   * Example: `propose(actions)`
2. **Describe Your Proposal**:
   * Attach a description to your proposal using the `describe` function.
   * Example: `describe(proposalId, description)`
3. **Propose and Describe**:
   * Combine the above two steps using the `propose_and_describe` function.
   * Example: `propose_and_describe(actions, description)`

#### 3. Voting on Proposals

After a proposal is created, it enters the voting phase where token holders can vote for or against (i.e. `yea` or `nay`) the proposal.

**How to Vote**

1. **Vote Yea or Nay**:
   * Use the `vote` function to cast your vote.
   * Example: `vote(proposalId, yea)` (where `yea` is `true` for yea, `false` for nay)

#### 4. Cancelling a Proposal

If you are the proposer, you can cancel your proposal if the voting period has not started. This allows proposers to correct errors identified during the voting start delay.

**How to Cancel a Proposal**

* Use the `cancel` function to cancel your proposal.
* Example: `cancel(proposalId)`

#### 5. Reporting a Breach

If you notice that the proposer's voting weight fell below the required proposal creation threshold during the voting period, you can report this breach, canceling the proposal.

**How to Report a Breach**

* Use the `report_breach` function with the timestamp at which the voting weight fell below the creation threshold during the voting period.
* Example: `report_breach(proposalId, breachTimestamp)`

#### 6. Executing a Proposal

If a proposal passes the voting phase, meaning it received at least `quorum` 'yea' votes and the simple majority voted in favor, it can be executed after the execution delay period.

**How to Execute a Proposal**

* Use the `execute` function to carry out the actions in the proposal.
* Example: `execute(proposalId, actions)`

### Configuration Parameters

The Governor contract has specific configuration parameters that determine how proposals and voting work:

* **Voting Start Delay**: 1 day (86400 seconds)
* **Voting Period**: 7 days (604800 seconds)
* **Voting Weight Smoothing Duration**: 1 day (86400 seconds)
* **Quorum**: 3,500,000 tokens (with 18 decimals)
* **Proposal Creation Threshold**: 100,000 tokens (with 18 decimals)
* **Execution Delay**: 1 day (86400 seconds)
* **Execution Window**: 30 days (2592000 seconds)

These parameters ensure a fair governance process, allowing ample time for voting and execution of proposals.
