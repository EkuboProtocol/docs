---
description: >-
  How the Ekubo DAO is structured, what it controls, how protocol revenue flows
  back to it, and Ekubo, Inc.'s role within it
title: "Governance"
---

Ekubo Protocol is governed by holders of the [EKUBO token](/user-guides/ekubo-token/). Governance is deliberately narrow in scope: the EVM V3 Core contracts are **ownerless and immutable**, so there is no privileged actor who can change how the AMM works or seize funds. What governance does control is the protocol's upgradeable deployments, its treasury, and the parameters of the periphery.

The contracts are open source in the [governance repository](https://github.com/EkuboProtocol/governance) and are themselves ownerless and non-upgradeable, apart from the Governor's ability to upgrade itself by proposal. Deployed addresses are listed in the [governance contracts reference](/reference/contracts/governance/).

## The three contracts

**EKUBO** is an ERC-20 on Ethereum, bridged to Starknet. It is the unit of voting weight.

**Staker** holds staked tokens and tracks delegation. Staking is not vote-escrow: there is no lockup, no decay, and no penalty for withdrawing. You stake to a delegate — often yourself — and can withdraw at any time.

Voting weight is not simply your staked balance. The Staker records delegation over time, and weight is the **average amount delegated to you** over a smoothing window ending when voting opens. This makes weight expensive to manufacture immediately before a vote.

**Governor** runs the proposal lifecycle and executes approved calls itself, so a passed proposal can make arbitrary calls — including `send_message_to_l1`, which is how it drives the owner proxies on other chains. (It also implements the account interface, but only so that proposals can be simulated off-chain.)

## Proposal lifecycle

```
propose → voting delay → voting period → execution delay → execution window → executed
```

A proposal commits to a set of calls by hash; those exact calls must be supplied again at execution. It passes only if it reaches quorum **and** receives strictly more `yea` than `nay` votes — a tie fails.

Current configuration:

| Parameter                        | Value           |
| -------------------------------- | --------------- |
| Voting start delay               | 1 hour          |
| Voting period                    | 4 days          |
| Voting weight smoothing duration | 1 day           |
| Quorum                           | 3,250,000 EKUBO |
| Proposal creation threshold      | 100,000 EKUBO   |
| Execution delay                  | 1 hour          |
| Execution window                 | 30 days         |

These are themselves governance-configurable, and each proposal is versioned against the configuration in effect when it was created — so a proposal created before a reconfiguration still runs under the old parameters. Read the current values directly from the Governor's `get_config` entrypoint.

Additional rules worth knowing: a proposer may have only one active proposal at a time, and a proposal can be cancelled only by its proposer and only before voting opens — the delay period exists so mistakes can be corrected. Execution is atomic and happens once; if a call reverts, the whole proposal can be retried within the execution window.

For the practical steps, see [Participate in governance](/user-guides/governance/).

## What governance controls

- **Starknet contracts** — Core, Positions, and the extensions are upgradeable in place. The extensions are owned directly by the Governor; Core and Positions are held by the RevenueBuybacks contracts, which the Governor owns and can reclaim from by proposal
- **The treasury** — assets held by the DAO, disbursed by proposal (including streamed payments)
- **Cross-chain deployments** — owner proxies on Ethereum, Base, Optimism, Arbitrum One, Robinhood Chain, Unichain, World Chain, Ink, MegaETH, Gnosis, and Polygon are configured so that a Starknet proposal can control contracts on other chains. See the [peripheral-contract ownership update](#peripheral-contract-ownership-update-9-october-2026) below for which contracts they own and for the status of production cross-chain message delivery
- **Periphery ownership** — the owner role on Positions and other periphery contracts, which can withdraw accumulated protocol fees to a recipient the owner chooses. It is not held by the DAO on every chain: on BNB Smart Chain and Monad, Ekubo, Inc. still owns the Positions and Orders contracts (see the [update](#peripheral-contract-ownership-update-9-october-2026) below). The fee _rate_ itself is not a governance parameter: it is immutable on EVM and a compile-time constant on Starknet, so changing it requires a new deployment

Notably _not_ controlled: the EVM V3 Core contract, which has no owner at all.

## Peripheral-contract ownership update (9 October 2026)

**Peripheral-contract ownership update — 9 October 2026.** Ekubo, Inc. has completed 33 direct ownership transfers of Positions, Orders and Auctions peripheral contracts to designated DAO owner proxies across 11 EVM chains: Ethereum, Base, Optimism, Arbitrum One, Robinhood Chain, Unichain, World Chain, Ink, MegaETH, Gnosis and Polygon. Six new owner proxies were deployed as part of this migration. The transfers were company-signed, board-approved `transferOwnership` transactions, not transactions executed under a DAO vote. No Governor proposal was created for the prepared P1, R1 or R2 drafts. P1 was withdrawn before proposal; R1 was superseded before proposal; the board stood down R2 on 9 October 2026. No ownership handover request or completion step remains pending.

**Six company-controlled contracts remain.** The Ekubo, Inc. company key `0x00000c771f6176268d5a9846e0956c3ef58597a1` still owns Positions and Orders v3.2.0 on BNB Smart Chain (two contracts), and Positions and Orders v3.1.1 and v3.2.0 on Monad (four contracts). Their DAO-control route remains subject to a separate board decision. Positions ownership permits withdrawal of accrued protocol fees to an owner-selected recipient and metadata/ownership administration; Orders ownership permits metadata/ownership administration, not funds withdrawal. These six contracts are not DAO-controlled.

**Production cross-chain delivery remains unproven.** Ownership and proxy configuration have been independently verified by Ekubo's security reviewer, and messaging paths have been tested on live-chain forks. However, no production DAO message has yet been delivered through any of the ten L2/sidechain owner proxies. The board accepted this residual and decided not to create the R2 reachability-proof proposal. Configured DAO ownership is not a demonstration or guarantee of production cross-chain message delivery. If a messaging route fails to deliver, affected owner-only functions, including fee withdrawal and metadata administration where applicable, could be unreachable until the route is restored. Such a delivery failure does not itself transfer or give access to user positions or funds, or change the immutable, ownerless EVM Core contracts.

The ownership migration did not withdraw fees, transfer user tokens or position NFTs, change protocol fee rates or fee recipients, create automatic fee remittances or buybacks, or change STONX economic rights. The accompanying chain-, version- and address-specific control matrix and transaction record identify the migrated contracts, new proxies and remaining company-controlled contracts. This is a dated ownership snapshot, not a claim that all deployments are DAO-controlled or that every cross-chain route has been exercised in production.

The per-contract transaction record, the owner proxies and the six contracts that remain company-owned are listed, with snapshot blocks, in [Peripheral-contract ownership](/reference/contracts/peripheral-ownership/).

## Revenue buybacks

Protocol fees are collected at the periphery — a share of the swap fees liquidity providers collect — and flow back to the DAO through the RevenueBuybacks contract.

The mechanism is permissionless: anyone can trigger it. It withdraws accumulated protocol fees and places a [TWAMM order](/user-guides/dollar-cost-average-orders/) selling them for EKUBO gradually over a configured window, rather than in a single market-moving trade. Proceeds are collected to the Governor. Order timing and duration bounds, and the pool fee used, are set by governance per token.

## Ekubo, Inc.'s role

Ekubo, Inc. is the Delaware C corporation that built the initial version of Ekubo Protocol, along with the [indexer](/products/indexer/), the interface, the governance contracts, and the API. It was founded by [Moody Salem](https://x.com/sendmoodz), and bootstrapped the Ekubo DAO in May 2024, distributing two thirds of total supply — one third by airdrop and one third sold by the DAO (see [EKUBO token](/user-guides/ekubo-token/)) — and governing actively from the start. The DAO received the largest [Starknet Catalyst Program grant](https://www.starknet.io/blog/announcing-the-catalyst-program-igniting-transformative-change/) in recognition of that work.

In July 2024 the DAO approved a proposal defining the company's role in exchange for a one-time grant of roughly $1.5M — intended to be the only grant the company ever requests. Under it, Ekubo, Inc. committed to:

- Develop the core contracts for the benefit of the DAO, and make source code available at the DAO's direction
- Design and implement a framework for returning protocol revenue to stakers — delivered as the revenue buybacks above
- Develop and host the interface, free to swap on, with a public feature prioritization process
- Maintain this documentation, provide developer support in the [Discord](https://discord.ekubo.org), and help delegates create proposals
- Operate the public API and open source the governance tooling

The company holds one third of the total EKUBO supply and has committed to **never sell** those tokens for as long as it exists, keeping it permanently aligned with the protocol.

### Where the ecosystem can contribute

Ekubo, Inc. deliberately does not cover everything. Areas that benefit from independent teams include liquidity provider tooling and automated liquidity management, advanced delegate and governance tooling, market analytics, aggregator and routing integrations, marketing and community management, and exchange listings. If you want to build in one of these areas, start a conversation in the [Discord](https://discord.ekubo.org).
