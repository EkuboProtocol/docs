---
description: >-
  Use Ekubo Wallet with local AI agents and WalletConnect dapps while keeping
  private keys, policies, and approvals in a native desktop application
title: "Wallet"
---

Ekubo Wallet is a native desktop wallet for Ethereum and EVM-compatible networks. It serves people, local AI agents, and WalletConnect dapps from one tray-first application, with encrypted storage and one signing authority.

The central rule is simple: an agent can inspect, simulate, propose, and wait for an onchain action, but it cannot approve the action, export a private key, or weaken the owner's policy. Those owner-only capabilities stay in the native application.

[Visit the Ekubo Wallet website](https://wallet.ekubo.org) for downloads, source links, and launch information.

## What agents can do

An authorized agent begins by reading the wallet and network inventory instead of guessing an account or chain. It can then read balances, portfolio state, trusted token metadata, and active policy; prepare transfers; fetch and verify an execution plan produced by an appropriate service; simulate exact calls; submit an approved request; and observe the final result.

The public [Ekubo MCP server](/products/mcp-server/) complements the wallet. It can resolve tokens, compare swap quotes, read Ekubo pools and positions, and prepare unsigned execution plans. The wallet independently fetches and verifies the selected plan, simulates it against current chain state, and owns signing and submission.

An agent must not treat a simulation as approval. If the current policy does not already allow an action, the wallet queues a native review and the agent waits until the owner approves or rejects it. Typed data and personal-message signatures always require native owner review.

### Example requests

- “Show my balances across every enabled EVM network.”
- “Swap 0.1 ETH for USDC on Base and show me every quote before I choose.”
- “Simulate this contract call and explain what will change before I approve it.”
- “Send 25 USDC to this address on Arbitrum.”
- “Propose a policy that only allows this contract call with no native value.”

## Connecting an agent

Ekubo Wallet detects Codex, Claude Code, Gemini CLI, Cursor, and opencode. Its automatic setup adds a credential-free `ekubo_wallet` MCP entry that contains the fixed loopback URL and OAuth mode. It does not write an access token, refresh token, authorization header, or client secret into an agent configuration file.

Start authentication from the agent while Ekubo Wallet is running. The wallet brings its native window forward, lets the owner choose a one-day, one-week, or one-month session, and requires operating-system authentication before granting access. Access tokens are short-lived, and refresh rotation cannot extend the absolute session lifetime chosen by the owner.

Claude Desktop uses the Ekubo Wallet MCP Bundle from the wallet release rather than the Claude Code configuration. Install the bundle from **Settings → Extensions → Advanced settings → Install Extension**. The adapter forwards only to the fixed local wallet endpoint and retains OAuth credentials in process memory, so restarting Claude Desktop can require authorization again.

## Security model

Ekubo Wallet separates owner and agent capabilities in its core authority:

| Capability                                           | Owner in the native app | Authorized agent |
| ---------------------------------------------------- | ----------------------- | ---------------- |
| Read public wallet, network, token, and policy state | Yes                     | Yes              |
| Simulate or propose an action                        | Yes                     | Yes              |
| Queue a transaction for review                       | Yes                     | Yes              |
| Approve or reject a request                          | Yes                     | No               |
| Install or replace policy                            | Yes                     | No               |
| Export a private key                                 | Yes                     | No               |
| Accept legal terms or change security settings       | Yes                     | No               |

Every native review starts on **Reject**. Approval remains unavailable until the complete review and exact payload have been viewed. Approving then requires operating-system authentication, after which the wallet reloads the request and policy and verifies that the reviewed document is still the one being signed.

Desktop state is held in a SQLCipher database. Private keys use the operating system's credential service. Exact calldata, typed data, message bytes, digests, warnings, Unicode controls, and visually confusable characters remain available in the review rather than being replaced by a friendly summary.

The local MCP server listens only on its fixed loopback endpoint and authenticates MCP requests with OAuth. It rejects browser-originated requests and requests with an unexpected host before reading the body. This boundary protects against accidental and unauthorized local clients; plaintext loopback traffic cannot defeat malicious software already running as the same operating-system user.

## Policies

Policy rules are ordered, and the first matching rule decides each call. A rule can allow or deny an action and can constrain the network, destination, native value, and calldata. Matchers are combined, so omitting a matcher means that field is unrestricted.

If no rule matches, the ordinary result is owner review. A matching deny rule rejects the complete transaction without an approval override. Every call in a batch must match an allow rule before it can proceed automatically.

An agent can read the active policy and propose a complete replacement bound to its current revision. Only the owner can inspect the permission diff and install the proposal with operating-system authentication. Prefer the narrowest rule that expresses the intended recurring operation; do not broaden policy merely to complete one request.

## WalletConnect

The wallet also accepts WalletConnect v2 pairing URIs copied from a dapp. Multiple sessions can be active at once. Account and chain requests, personal signing, typed data, transactions, and EIP-5792 requests enter the same owner review path as other native requests.

WalletConnect pairings stay in memory. They do not persist or reconnect after the application restarts, and explicit Quit disconnects every live session.

## Desktop packages

The wallet is distributed as a notarized macOS app in a DMG, a signed per-user Windows installer, and an AppImage or DEB package for Linux. Published packages and update metadata are signed, and the application verifies an update before shutting down to install it.

Use [wallet.ekubo.org](https://wallet.ekubo.org) for current downloads and release notes. Questions about setup or behavior are welcome in the [Ekubo Discord](https://discord.ekubo.org).
