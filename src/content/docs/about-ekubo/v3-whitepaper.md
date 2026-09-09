---
description: "Ekubo V3's shared liquidity architecture: a common AMM and settlement layer for independent products, integrations, and AI agents."
title: "Ekubo V3: Shared Liquidity as a Public Good"
---

**Date:** <time datetime="2025-11-19">November 19, 2025</time> · **Last updated:** <time datetime="2026-09-09">September 9, 2026</time>

## Motivation

Launching an automated market maker (AMM) often means deploying another copy of familiar contracts, attracting a separate base of liquidity, and rebuilding the integrations around it. Traders encounter fragmented markets, while liquidity providers and developers must decide which deployments to support. Each new brand or version can repeat much of the same work without improving the underlying market design.

Ekubo V3 separates the market infrastructure from the products built on it. Its central contract, Core, implements the AMM, holds tokens, and accounts for swaps and liquidity positions. Independent teams can build their own interfaces, contracts, and revenue models around the same deployment. A new product can use existing pools instead of requiring users to move their liquidity to another fork.

The aim is to make liquidity and settlement common infrastructure. Teams can compete on distribution, execution workflows, asset curation, and user experience while contributing to a shared market. Tooling developed for that market can serve many products, and transactions that combine its pools can settle without transferring intermediate tokens between separate AMM contracts.

This paper describes the V3 EVM architecture. Sharing occurs within a Core deployment on a particular chain; deploying the same code on another chain does not combine their balances or liquidity.

## The AMM Encoded in Core

Core implements concentrated liquidity using constant-product swap math. Liquidity providers choose price ranges, and their liquidity participates while the market price is inside those ranges. The underlying tick grid advances in increments of 0.01 basis points, with each pool's tick spacing determining the available position boundaries. This gives market makers fine control over where they supply liquidity.

Core also supports full-range and stableswap configurations. These configurations belong to the shared implementation, so a team can select the appropriate pool design without maintaining its own copy of the swap math. The implementation is available in the [Core contract](https://github.com/EkuboProtocol/evm-contracts/blob/main/src/Core.sol) and [pool configuration code](https://github.com/EkuboProtocol/evm-contracts/blob/main/src/types/poolConfig.sol).

A pool is identified by its token pair and configuration, including its fee, pool type parameters, and extension. Products using the same pool key on the same Core access the same pool. Different configurations remain distinct markets, even though Core holds their tokens. Position ownership and accounting also remain separate: sharing a pool does not give one product control over another product's positions.

## Engineering for Gas Efficiency

Core reduces the storage access and token movement needed to execute a trade. Frequently accessed state is packed into compact representations, and critical arithmetic uses low-level operations. These choices matter because every transaction pays for the work performed by the EVM.

The price representation illustrates this approach. Core stores the square-root price in a 96-bit dynamic fixed-point format whose two highest bits select the scale. This leaves room for the current tick and active liquidity in the same 256-bit storage word. The encoding and layout are defined in [SqrtRatio](https://github.com/EkuboProtocol/evm-contracts/blob/main/src/types/sqrtRatio.sol) and [PoolState](https://github.com/EkuboProtocol/evm-contracts/blob/main/src/types/poolState.sol).

Compact state and careful arithmetic reduce overhead, but their effect depends on the transaction. Tick crossings, extension logic, token behavior, and the route itself still affect gas consumption. The design should be evaluated through measurements of comparable operations; it does not establish that further optimization is impossible.

## Licensees and White-Labeled AMMs

Independent teams can build products around Core under the Ekubo DAO Shared Revenue License. These licensees choose how users access the market, which assets and pools they feature, and how they earn revenue. Their products may use routers, position managers, and extensions to compose the underlying operations into a particular trading or liquidity-management experience.

The standard positions contract provides one way to manage user liquidity above Core. A licensee can deploy it with its own fee parameters, including a share of collected swap fees and a fee on liquidity withdrawals. In the reference [Positions implementation](https://github.com/EkuboProtocol/evm-contracts/blob/main/src/Positions.sol), those parameters are set at construction and are immutable for that deployment. Different position managers can therefore offer different economics while supplying liquidity to the same Core pool.

This arrangement allows products to share liquidity without sharing their entire business model. A trader can reach a pool through several interfaces, and liquidity in that pool can serve the resulting order flow. The benefit depends on products actually selecting and routing into common pools; using the same Core alone does not eliminate fragmentation across configurations.

## Extensions: Shared Protocol Features

Extensions are contracts that add behavior at defined points in Core's operations. They let builders reuse protocol features while keeping the underlying AMM implementation in one place. A pool's configuration selects its extension, so extension behavior is part of the identity and execution requirements of that pool.

The reference implementation includes an [Oracle](https://github.com/EkuboProtocol/evm-contracts/blob/main/src/extensions/Oracle.sol) that records cumulative observations for supported pools, a [TWAMM](https://github.com/EkuboProtocol/evm-contracts/blob/main/src/extensions/TWAMM.sol) that executes orders over time, and [MEV Capture](https://github.com/EkuboProtocol/evm-contracts/blob/main/src/extensions/MEVCapture.sol), which collects additional swap fees based on price movement and accounts for them as pool fees. These features support different market requirements without requiring each licensee to reproduce them.

Products can offer access to pools with different extensions or develop new extensions of their own. A single pool key contains one extension address; combining several behaviors in one pool requires an extension designed to compose them. Integrators must account for those behaviors when quoting and executing trades, even when they already support Core.

## Network Effects From a Singleton Core

### Tooling and Analytics

A common contract interface and event model give indexers, analytics platforms, and monitoring tools a reusable foundation. Once an integration understands Core's pools, swaps, and liquidity accounting, it can support additional products using that deployment without indexing another fork of the AMM.

Product-specific attribution, position managers, and extension behavior may still require additional work. The shared architecture concentrates that work around a common market model, allowing improvements to pool discovery and monitoring to benefit multiple teams.

### Integrations and Routing

Routers can discover and compare pools within Core using a common pool identity and accounting model. A new frontend that uses an existing pool does not create another venue for the router to integrate. A new pool configuration can be evaluated within the same framework, subject to any requirements imposed by its extension.

This makes it possible for distribution to grow independently of the number of AMM deployments. More products can bring order flow to existing liquidity, while more accessible liquidity can make those products useful to additional traders. The architecture enables this feedback; it does not guarantee deeper liquidity or better execution for every trade.

### Gas Efficiency Across Licensees

A route spanning separate AMM contracts generally needs to transfer intermediate tokens between their custody addresses, either directly or through a router. Within a single Core, the output of one operation can instead offset the input obligation of another through internal accounting.

For example, an A-to-B swap followed by a B-to-C swap can settle the intermediate B balance without an ERC-20 transfer of B out of Core and back in. Both swaps still execute and update their respective pools. The saving comes from netting token obligations, not from treating a route through two pools as one swap.

The same principle applies when products operated by different licensees compose operations on a shared Core. Their branding does not require separate custody, and their use of different position managers need not introduce additional AMM hops.

## Flash Accounting as a Supporting Feature

Flash accounting makes this settlement model possible. During a lock, Core tracks token obligations as operations execute, allowing swaps and liquidity changes to be combined before settlement. The EVM implementation uses transient storage for this accounting and reverts if any debt remains outstanding when the lock ends. These checks are implemented in [FlashAccountant](https://github.com/EkuboProtocol/evm-contracts/blob/main/src/base/FlashAccountant.sol).

Core also supports saved balances that contracts can retain and reuse across transactions. Those balances are accounted for by the locker address, token pair, and a salt; custody in the same contract does not make them freely accessible to other callers.

Together, net settlement and saved balances let builders compose operations with fewer token transfers. The singleton provides a common place for those operations to occur, and flash accounting provides the mechanism for settling them efficiently.

## Permissionless, Ownerless, and Fee-Externalized

The V3 EVM Core has no owner role or administrative switch for imposing a global protocol fee. Pool creation and extension registration are governed by contract validation rather than a discretionary approval process. These properties concern Core itself; position managers, extensions, and other contracts must be evaluated separately.

The code can be deployed and integrated under the [Ekubo DAO Shared Revenue License](https://github.com/EkuboProtocol/evm-contracts/blob/main/LICENSE). The license governs revenue sharing and other obligations, including notices and distribution terms. Its definition of Protocol Revenue is broader than the fee setting on a particular positions contract, so a zero setting alone does not establish that a product has no revenue-sharing obligation.

Core's accounting is separate from those licensing obligations. Products can implement their revenue models in contracts above Core, while the shared AMM continues to account for pool liquidity and trading fees. This separation places product economics at the integration layer and allows the same market infrastructure to support different commercial arrangements.

## Shared Liquidity for AI Agents

AI lowers the cost of writing software, including another AMM fork. It also lowers the cost of comparing and using the markets that software creates. Our thesis is that the second effect will make execution efficiency more important: as agents take on more trading and liquidity-management work, measurable outcomes should carry more weight in where activity goes.

An agent can be more patient and less influenced by branding than a person navigating trading websites. Given a user's objectives and deadline, it can compare more routes, revisit quotes, wait for an acceptable execution cost, or evaluate an order that executes over time. It need not stop at the first familiar interface. That behavior depends on the agent's instructions, available tools, and the cost of running them; agents are not automatically impartial or optimal. But tools that expose comparable quotes and explicit transaction costs make it practical to choose on economic grounds.

Ekubo provides that access through its [hosted MCP server](/products/mcp-server/) at `https://mcp.ekubo.org/mcp`. Agents can resolve tokens, request swap quotes with unsigned execution plans, inspect pools and positions, and prepare liquidity operations or TWAMM orders. The service exposes these operations as structured tools, so an agent can work directly with the market without navigating a frontend. Its swap quoting includes external providers alongside Ekubo, making comparison part of the workflow. The [live service catalog](https://mcp.ekubo.org/) describes the available capabilities.

[Ekubo Wallet](/wallet/) completes the execution path. An agent passes the selected unsigned plan to the local wallet, which independently retrieves and verifies it, simulates the exact calls, and checks the user's signing policy. The wallet signs and submits transactions allowed by that policy, queues transactions requiring owner review, and rejects those prohibited by policy. The hosted MCP server supplies data and prepares actions; it does not hold wallet keys or authorize spending. The [agent integration guide](/wallet/agents/) explains how the two tools work together.

For example, a user can ask an agent to acquire an asset within a specified budget and time window. The agent can obtain current quotes, compare expected proceeds and transaction costs, and bring a selected plan to the wallet for simulation and authorization. If immediate execution does not meet the user's limits, the agent can revisit the decision later or propose a TWAMM order where supported. Waiting introduces price risk, and simulation does not guarantee later execution, so the user's constraints remain part of the decision.

This is where Core's engineering becomes commercially relevant. Lower gas overhead can improve a route's net economics; shared liquidity lets multiple products reach an existing market; and flash accounting avoids intermediate token transfers when operations settle within Core. An agent comparing execution plans has a reason to account for each of these properties. A fork may be easier to write, but it still has to attract liquidity and order flow, support integrations, and compete on actual execution costs. We expect competition among agents to increase the value of those technical advantages, while making it easier for new products to access them through the same tools.

## How It Feels to Use Ekubo

### For Traders

Traders choose an interface and submit a trade against the pools it supports. Several interfaces can reach the same liquidity, so choosing a different product need not mean moving to a different market. Execution still depends on the selected route, available liquidity, fees, and transaction limits.

### For Liquidity Providers

A liquidity provider's position can serve trades arriving from any product that routes into its pool. Supporting another frontend does not inherently require creating another position or migrating funds. Concentrating liquidity increases exposure to fees while the position is in range, but also increases divergence-loss exposure and the likelihood of going out of range; shared distribution does not remove those tradeoffs.

### For Licensees and Builders

Builders can focus on the product around the market: how users discover opportunities, express their intentions, manage positions, and authorize transactions. They can reuse Core and compatible integrations while taking responsibility for their own contracts, extension choices, and economics.

## Summary

Ekubo V3 gives independent products a common AMM and settlement layer. Concentrated liquidity, configurable pool designs, and extensions support different market needs within a shared Core deployment. Compact state and flash accounting reduce overhead, while common interfaces make tooling reusable across products.

The long-term opportunity is a market that can support many brands, business models, and automated agents without requiring each to recreate its liquidity infrastructure. As agents make market comparison cheaper, we expect execution costs and accessible liquidity to become stronger reasons to choose that foundation. Ekubo’s hosted MCP server and wallet turn this architecture into a workflow agents can use today.
