---
description: Connect an AI agent and use Ekubo Wallet as its local custody and execution boundary
title: "Use Ekubo Wallet with AI agents"
---

Ekubo Wallet exposes a local Model Context Protocol (MCP) server to supported agents on the same computer. The agent receives a restricted wallet capability; owner-only capabilities remain in the native application.

Follow the [installation guide](/wallet/install/) to configure an agent and authorize a session. Configuration alone does not grant access. The agent obtains OAuth credentials only after sign-in is started from the agent and approved by the owner through the wallet.

## How a request works

1. The agent reads the wallet and enabled-network inventory instead of guessing an account or chain.
2. It reads balances, trusted token metadata, and the active signing policy as needed.
3. It constructs a transfer or obtains an exact execution plan from an appropriate service.
4. Ekubo Wallet simulates the exact calls against the configured network.
5. The active policy allows the transaction, denies it, or sends it to the owner for native review.
6. The agent waits until the request reaches a final result.

A simulation is not approval. If a request is waiting on the owner, review it in Ekubo Wallet's **Inbox**. The agent should continue waiting rather than returning a request identifier and treating the task as finished.

Typed-data and personal-message signatures always require native owner review. An agent cannot export a key, accept legal terms, approve its own request, or install a proposed policy.

## Local wallet and public Ekubo service

Agent setup installs two complementary MCP entries:

- The local Ekubo Wallet entry reads wallet state, simulates, queues reviews, signs, submits, and reports results.
- The public Ekubo service reads protocol data and prepares unsigned actions such as swaps and liquidity operations. It receives no additional authority over the wallet.

The local wallet independently retrieves and verifies supported execution-plan artifacts. It does not trust a friendly description in place of the exact calls it will simulate and display.

## Example requests

- “Show my balances across every enabled EVM network.”
- “Compare quotes for this swap and let me choose before anything is submitted.”
- “Simulate this contract call and explain the result before I approve it.”
- “Send this amount to this address on the selected network.”
- “Propose a narrow policy for this recurring contract call.”

Addresses, chain IDs, amounts, calldata, typed data, and message bytes are exact values. Check them in the native [approval review](/wallet/approvals/) rather than relying only on an agent's summary.

## Revoke access

Open **Settings** and find **Agent sessions** to review authorized sessions and revoke one. Revocation invalidates that client's active wallet credentials. Removing an MCP entry from an agent's configuration is separate from revoking credentials already issued to it.
