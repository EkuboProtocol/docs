---
description: Connect an AI agent and use Ekubo Wallet as its local custody and execution boundary
title: "Use Ekubo Wallet with AI agents"
---

Ekubo Wallet exposes a local Model Context Protocol (MCP) server to supported agents on the same computer. The agent receives a restricted wallet capability; owner-only capabilities remain in the native application. The local connection uses a versioned stdio bridge and same-user operating-system IPC. It has no HTTP listener, OAuth flow, bearer token, or client secret.

Follow the [installation guide](/wallet/install/) to configure a supported harness. Installing the fixed, credential-free connection entry is not an approval and grants no owner capability.

## How a request works

1. The agent reads the wallet and enabled-network inventory instead of guessing an account or chain.
2. It reads balances, trusted token metadata, and the active signing policy as needed.
3. It obtains an exact execution plan from an appropriate producer. The wallet does not construct transfers, protocol actions, or calldata.
4. Ekubo Wallet simulates the exact calls against the configured network.
5. The active policy allows the transaction, denies it, or sends it to the owner for native review.
6. The agent waits until the request reaches a final result.

A simulation is not approval. If a request is waiting on the owner, review it in Ekubo Wallet's **Inbox**. The agent should continue waiting rather than returning a request identifier and treating the task as finished.

Typed-data and personal-message signatures always require native owner review. An agent cannot export a key, accept legal terms, approve its own request, or install a proposed policy.

When a producer returns an `artifact_reference`, the agent must pass that JSON object to the wallet verbatim. It must not encode the object as a JSON string, rename fields, or reconstruct the execution plan. The wallet fetches the body itself and verifies the declared integrity and byte count.

The `reference` argument is an object, never quoted JSON text. Its execution-plan shape is:

```json
{
  "kind": "artifact_reference",
  "artifact_type": "execution_plan",
  "url": "https://…",
  "integrity": {
    "algorithm": "keccak256",
    "value": "0x…"
  },
  "bytes": 1234
}
```

Those values are illustrative only. Copy the complete object returned by the producer; do not substitute placeholders or reuse an expired reference.

## Local wallet and public Ekubo service

For harnesses whose configuration supports both local and remote MCP, agent setup installs two complementary entries:

- The local Ekubo Wallet entry reads wallet state, simulates, queues reviews, signs, submits, and reports results.
- The public Ekubo service at `https://mcp.ekubo.org/mcp` reads protocol data and prepares unsigned actions such as transfers, swaps, and liquidity operations. It receives no additional authority over the wallet.

The hosted service can temporarily store exact execution plans and other artifact bodies so the wallet can retrieve them by reference. Those plans can identify a sender and intended action. The local wallet independently retrieves, verifies, and simulates supported artifacts. It does not trust a friendly description in place of the exact calls it will display and potentially sign. Read [Security and privacy](/wallet/security/) for the service boundary.

Claude Desktop's configuration file receives only the local entry. Add the public service separately as an account-level custom connector through **Customize → Connectors**.

## Harness limitations

Supported harnesses include Codex, Claude Code, Claude Desktop, Gemini CLI, Cursor, and OpenCode. The ChatGPT desktop app can use the installed local MCP connection from its **Work** or **Code** tab; there is no ChatGPT wallet plugin.

Harness providers apply their own tool-use rules before a request reaches Ekubo Wallet. Some clients classify transaction submission as financial activity and refuse to call the wallet even though the wallet would require its own policy check or native review. Claude Desktop is a known example: use **Code** mode for the best chance of reaching wallet tools. If a harness still refuses, move the task to another supported harness. Changing harnesses does not weaken Ekubo Wallet's local policy, simulation, or owner-review boundary.

## Example requests

- “`/loop` Manage my USDC/USDG liquidity position on Ethereum. Claim fees, rebalance when the range drifts, and ask before every transaction.”
- “Claim all fees from my ve33 votes, sell balances worth more than their gas, and max stake the STONX proceeds.”
- “Compare moving half my ETH/USDC liquidity into USDC/USDG using current pool data. Show expected balances, gas, and range risk before preparing anything.”
- “Find every nonzero token approval from my company wallet, rank the risky spenders, and prepare revocations for the ones I choose.”
- “Propose a policy that only permits this recurring action, including exact constraints on its tuple arguments.”

Addresses, chain IDs, amounts, calldata, typed data, and message bytes are exact values. Check them in the native [approval review](/wallet/approvals/) rather than relying only on an agent's summary.

## Remove a connection

Open **Settings** and use the detected-agent controls to remove wallet-managed entries. This removes only the exact `ekubo_wallet` local entry and, where supported, the `ekubo` hosted companion entry. The wallet does not issue a persistent local bearer credential to revoke. Claude Desktop account connectors are managed in Claude's **Customize → Connectors** screen.
