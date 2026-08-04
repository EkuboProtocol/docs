---
description: >-
  How the Ekubo DAO is structured, what it controls, how protocol revenue flows
  back to it, and Ekubo, Inc.'s role within it
---

# Governance

Ekubo Protocol is governed by holders of the [EKUBO token](../user-guides/ekubo-token.md). Governance is deliberately narrow in scope: the EVM V3 Core contracts are **ownerless and immutable**, so there is no privileged actor who can change how the AMM works or seize funds. What governance does control is the protocol's upgradeable deployments, its treasury, and the parameters of the periphery.

The contracts are open source in the [governance repository](https://github.com/EkuboProtocol/governance) and are themselves ownerless and non-upgradeable, apart from the Governor's ability to upgrade itself by proposal.

## The three contracts

**EKUBO** is an ERC-20 on Ethereum, bridged to Starknet. It is the unit of voting weight.

**Staker** holds staked tokens and tracks delegation. Staking is not vote-escrow: there is no lockup, no decay, and no penalty for withdrawing. You stake to a delegate — often yourself — and can withdraw at any time.

Voting weight is not simply your staked balance. The Staker records delegation over time, and weight is the **average amount delegated to you** over a smoothing window ending when voting opens. This makes weight expensive to manufacture immediately before a vote.

**Governor** runs the proposal lifecycle and executes approved calls. It is a Starknet account contract, so a passed proposal can execute arbitrary calls — including sending messages to Ethereum.

## Proposal lifecycle

```
propose → voting delay → voting period → execution delay → execution window → executed
```

A proposal commits to a set of calls by hash; those exact calls must be supplied again at execution. It passes only if it reaches quorum **and** receives strictly more `yea` than `nay` votes — a tie fails.

Current configuration:

| Parameter | Value |
| --- | --- |
| Voting start delay | 1 hour |
| Voting period | 4 days |
| Voting weight smoothing duration | 1 day |
| Quorum | 3,250,000 EKUBO |
| Proposal creation threshold | 100,000 EKUBO |
| Execution delay | 1 hour |
| Execution window | 30 days |

These are themselves governance-configurable, and each proposal is versioned against the configuration in effect when it was created — so a proposal created before a reconfiguration still runs under the old parameters. Read the current values directly from the Governor's `get_config` entrypoint.

Additional rules worth knowing: a proposer may have only one active proposal at a time, and a proposal can be cancelled only by its proposer and only before voting opens — the delay period exists so mistakes can be corrected. Execution is atomic and happens once; if a call reverts, the whole proposal can be retried within the execution window.

For the practical steps, see [Participate in governance](../user-guides/governance.md).

## What governance controls

* **Starknet contracts** — Core, Positions, and the extensions on Starknet are upgradeable in place and owned by the Governor
* **The treasury** — assets held by the DAO, disbursed by proposal (including streamed payments)
* **Cross-chain deployments** — owner proxies on Ethereum, Arbitrum, Optimism, Base, and Robinhood Chain let a Starknet proposal control contracts on other chains
* **Periphery parameters** — such as the protocol fee applied by the Positions contract

Notably *not* controlled: the EVM V3 Core contract, which has no owner at all.

## Revenue buybacks

Protocol fees are collected at the periphery — a share of the swap fees liquidity providers collect — and flow back to the DAO through the RevenueBuybacks contract.

The mechanism is permissionless: anyone can trigger it. It withdraws accumulated protocol fees and places a [TWAMM order](../user-guides/dollar-cost-average-orders.md) selling them for EKUBO gradually over a configured window, rather than in a single market-moving trade. Proceeds are collected to the Governor. Order timing and duration bounds, and the pool fee used, are set by governance per token.

## Ekubo, Inc.'s role

Ekubo, Inc. is the Delaware C corporation that built the initial version of Ekubo Protocol, along with the [indexer](indexer.md), the interface, the governance contracts, and the API. It was founded by [Moody Salem](https://x.com/sendmoodz), and bootstrapped the Ekubo DAO in May 2024 — which distributed over 95% of total supply and passed 8 proposals in its first two months, and received the largest [Starknet Catalyst Program grant](https://www.starknet.io/blog/announcing-the-catalyst-program-igniting-transformative-change/) in recognition of that work.

In July 2024 the DAO approved a proposal defining the company's role in exchange for a one-time grant of roughly $1.5M — intended to be the only grant the company ever requests. Under it, Ekubo, Inc. committed to:

* Develop the core contracts for the benefit of the DAO, and make source code available at the DAO's direction
* Design and implement a framework for returning protocol revenue to stakers — delivered as the revenue buybacks above
* Develop and host the interface, free to swap on, with a public feature prioritization process
* Maintain this documentation, provide developer support in the [Discord](https://discord.ekubo.org), and help delegates create proposals
* Operate the public API and open source the governance tooling

The company holds one third of the total EKUBO supply and has committed to **never sell** those tokens for as long as it exists, keeping it permanently aligned with the protocol.

### Where the ecosystem can contribute

Ekubo, Inc. deliberately does not cover everything. Areas that benefit from independent teams include liquidity provider tooling and automated liquidity management, advanced delegate and governance tooling, market analytics, aggregator and routing integrations, marketing and community management, and exchange listings. If you want to build in one of these areas, start a conversation in the [Discord](https://discord.ekubo.org).
