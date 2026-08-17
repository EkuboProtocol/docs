---
description: >-
  Use Ekubo Wallet with AI agents and WalletConnect dapps while keeping keys,
  policies, and approvals in a native desktop application
title: "Ekubo Wallet"
---

Ekubo Wallet is a native desktop wallet for Ethereum and EVM-compatible networks. It gives people, local AI agents, and WalletConnect dapps one place to use accounts while keeping private keys and owner-only decisions inside the wallet application.

This section is the canonical landing page for Ekubo Wallet information, setup, and security documentation.

## What the wallet does

Ekubo Wallet can hold multiple accounts, show balances across enabled networks, simulate and submit transactions, sign messages and typed data, connect to dapps through WalletConnect, and serve as a local wallet for supported AI agents.

An agent can inspect public wallet state, obtain exact actions from producer services, ask the wallet to simulate and submit them, and wait for the result. The wallet does not prepare transfers, protocol actions, or calldata. An agent cannot approve a request, export a private key, install a signing policy, or change security-sensitive settings. Those actions stay in the native application and require the owner where appropriate.

| Task                                      | Where it happens                    |
| ----------------------------------------- | ----------------------------------- |
| Create or import an account               | Ekubo Wallet                        |
| Read balances and enabled networks        | Ekubo Wallet or an authorized agent |
| Prepare an Ekubo swap or liquidity action | Public Ekubo MCP service            |
| Simulate, review, sign, and submit        | Ekubo Wallet                        |
| Approve a request or change permissions   | Owner in Ekubo Wallet               |

The public [Ekubo MCP server](/products/mcp-server/) complements the wallet. It can resolve tokens, compare swap quotes, read Ekubo pools and positions, and prepare unsigned execution plans. The wallet independently retrieves the selected plan, simulates it against current chain state, and owns signing and submission.

Because the wallet executes plans rather than implementing protocols, its coverage extends well past Ekubo — currently 0x, Across, Aave V3, Morpho, Sky, and Lido as well — and grows without a wallet update. See [Supported protocols](/wallet/protocols/), which also covers what makes a third-party MCP server compatible.

## Get started

1. [Install Ekubo Wallet](/wallet/install/) and create or import an account.
2. [Connect an AI agent](/wallet/agents/) or [pair a dapp with WalletConnect](/wallet/walletconnect/).
3. Learn how [native reviews](/wallet/approvals/) and [signing policies](/wallet/policies/) decide what can be signed.
4. Read the [security and privacy model](/wallet/security/) to understand what the wallet protects and where its boundaries end.

Questions about setup or behavior are welcome in the [Ekubo Discord](https://discord.ekubo.org).
