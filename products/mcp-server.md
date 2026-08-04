---
description: >-
  Connect an AI agent to Ekubo: quotes, pool and position data, and unsigned
  execution plans over the Model Context Protocol
---

# MCP server

Ekubo runs a public [Model Context Protocol](https://modelcontextprotocol.io/) server at **`https://mcp.ekubo.org/mcp`**. It gives AI agents first-class access to Ekubo — resolving tokens, quoting swaps, reading pools and positions, and building transactions — without scraping a web interface.

The server is **non-custodial and read-only with respect to keys**. It never holds funds, never signs, and never submits. Tools that produce a transaction return an unsigned *execution plan*; signing and submission happen in the user's own wallet tooling.

## Connecting

The server speaks Streamable HTTP and requires no authentication. Add it to any MCP-capable client:

```json
{
  "mcpServers": {
    "ekubo": {
      "type": "http",
      "url": "https://mcp.ekubo.org/mcp"
    }
  }
}
```

Most clients also accept it from the command line — for example, `claude mcp add --transport http ekubo https://mcp.ekubo.org/mcp`.

## What it can do

Roughly fifty tools, grouped by what you're trying to accomplish:

| Area | Capabilities |
| --- | --- |
| **Tokens** | Search the canonical token list by symbol, or look up exact chain/address pairs in batches. Ordered by visibility priority so the preferred token wins ambiguous symbol matches. |
| **Swaps** | Quote a same-chain swap across every available source (Ekubo and 0x) or a cross-chain bridge (Across), then prepare an execution plan for the source you choose. |
| **Pools** | Read pool state and liquidity, derive pool IDs, decode pool configs, initialize pools, and correct a mispriced pool. |
| **Liquidity positions** | List positions by owner, inspect a position, and prepare deposits, withdrawals, earnings claims, and transfers. |
| **DCA / TWAMM** | Place, collect, and stop orders, and execute virtual orders. |
| **[Ve33](ve33.md)** | Stake, vote, extend, split, merge, increase, withdraw, reinvest, and claim fees — plus current allocations and a STONX allocation recommendation. |
| **Rewards** | List claimable [rewards](rewards.md) for an owner and prepare claims; surface boosted-fee, incentive, and projected ve(3,3) opportunities ranked by APR. |
| **Utilities** | Read balances and allowances, revoke approvals, wrap and unwrap tokens, expand oracle capacity, and trigger revenue buybacks. |

It also publishes **resources** that document its own conventions — the canonical agent workflow, the LP position workflow, the Ve33 workflow, quote semantics across providers, the execution-plan contract, and a chain-indexed directory of deployed contract addresses. Agents can read these directly rather than guessing at usage.

## The execution plan boundary

This is the part worth understanding before building on it.

Preparation tools never return "a transaction to send" loosely. They return an `execution_plan`: a signer-neutral, ordered sequence of unsigned calls, each encoded two ways —

* `transaction` — decimal `chain_id`, `value`, and optional `gas` with exact `from`, `to`, and `data`, for wallet APIs that take transaction objects
* `eip1193` — ready-to-forward `eth_call`, `eth_estimateGas`, and `eth_sendTransaction` requests with hexadecimal quantities, for JSON-RPC providers

The plan is the boundary between the MCP server and whatever signs. The rules that keep it safe:

* **Bind the sender first.** Choose the signing account before preparing, and pass that exact address. After preparation, the plan's `chain_id` and sender must match the wallet's observed chain and account — a mismatch invalidates the plan rather than being silently rewritten.
* **Pass the plan through unchanged.** The wallet simulates, presents, authorizes, and submits it. Ordering is preserved; a wallet that supports batching may execute the steps atomically.
* **Let the wallet own authorization.** The wallet's own approval flow is the confirmation step — an agent should not add a second one on top.

## A typical swap

1. Resolve the tokens by symbol or address, and show the user the chains and addresses chosen.
2. Convert the user's amount to base units without floating-point arithmetic.
3. Request an exact-input or exact-output quote. Every available source is returned; the server does not pick one for you. Individual provider failures are reported separately without invalidating the quotes that succeeded.
4. Prepare the swap with the chosen source, slippage tolerance, and sender. This refreshes that provider's quote and produces the calldata.
5. Hand the complete plan to the wallet, which simulates and executes it.

For "swap my entire balance" requests there is an extra step: read the exact on-chain balance first, rather than trusting a displayed number.

## Notes

* Supported on EVM chains, including Robinhood Chain (chain ID **4663** — the L2, not the brokerage).
* The server is versioned and advertises `listChanged` for both tools and resources, so clients are notified when its surface changes.
* Underlying protocol data comes from the same public [Ekubo API](../reference/ekubo-api/README.md) and [Quoter API](../reference/quoter-api.md) documented here, so results agree with the interface and with your own integrations.

Questions or problems? Ask in the [Discord](https://discord.ekubo.org).
