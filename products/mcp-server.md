---
description: >-
  Connect an AI agent to Ekubo: quotes, pool and position data, and unsigned
  execution plans over the Model Context Protocol
---

# MCP server

Ekubo runs a public [Model Context Protocol](https://modelcontextprotocol.io/) server at **`https://mcp.ekubo.org/mcp`**. It gives AI agents first-class access to Ekubo — resolving tokens, quoting swaps, reading pools and positions, and building transactions — without scraping a web interface.

The server is **non-custodial and read-only with respect to keys**. It never holds funds, never signs, and never submits. Tools that produce a transaction return a reference to an unsigned *execution plan*; signing and submission happen in the user's own wallet tooling.

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
| **Tokens** | Search the canonical token list by symbol, or look up exact chain/address pairs in batches of up to 1,000. Ordered by visibility priority so the preferred token wins ambiguous symbol matches. |
| **Swaps** | One call returns every available quote — Ekubo and 0x for same-chain swaps, Across for cross-chain — each option already carrying the execution plan that executes it, so there is no separate preparation step. |
| **Pools** | Read pool state and liquidity, list pool keys, derive pool IDs, decode pool configs, initialize pools, and correct a mispriced pool. |
| **Liquidity positions** | List positions by owner, inspect a position, find candidate pools for a position, and prepare deposits, withdrawals, earnings claims, and transfers. |
| **DCA / TWAMM** | Place, collect, and stop orders, and execute virtual orders. |
| **[Ve33](ve33.md)** | Stake, vote, reallocate, extend, split, merge, increase, withdraw, reinvest, and claim fees — plus current allocations and a STONX allocation recommendation. |
| **[Auctions](../reference/contracts/evm-v3.md)** | Create an auction, complete it, and collect creator proceeds. |
| **Rewards** | List claimable [rewards](rewards.md) for an owner and prepare claims, including recovery fund claims; surface boosted-fee, incentive, and projected ve(3,3) opportunities ranked by APR. |
| **Utilities** | Revoke approvals, wrap and unwrap tokens, boost a pool manually, expand oracle capacity, unwrap old gEKUBO, and trigger revenue buybacks. |

It also publishes **resources** that document its own conventions — the canonical agent workflow, the LP position workflow, the Ve33 workflow, quote semantics across providers, the execution-plan handoff, the data API's OpenAPI spec, and a chain-indexed directory of deployed contract addresses. Agents can read these directly rather than guessing at usage.

## The execution plan boundary

This is the part worth understanding before building on it.

Preparation tools never return "a transaction to send" loosely — and they do not return the plan inline either. Every executable preparation returns an `execution_plan_reference`: an artifact-reference envelope naming where the server stored the plan body, an integrity block (the keccak256 of the exact stored bytes plus their byte count), and a summary carrying the plan's `chain_id`, sender, and step count for sanity checks. The stored body — a signer-neutral, ordered sequence of unsigned calls — is the canonical boundary between the MCP server and whatever signs.

The rules that keep the boundary safe:

* **Relay the reference, not the body.** The agent passes the envelope unchanged to the wallet, which fetches the body over HTTPS, recomputes the integrity digest, checks the byte count, and refuses a mismatch. The agent in between never fetches, restates, or reconstructs the plan itself.
* **No timestamps travel in the envelope.** A plan's validity is expressed by the deadline inside its calldata and enforced by the wallet's simulation against current chain state. An expired reference simply 404s on fetch, and the fix is to re-run the preparation for fresh state and calldata.
* **Bind the sender first.** Choose the signing account before preparing, and pass that exact address. After preparation, the envelope summary's `chain_id` and sender must match the wallet's observed chain and account — a mismatch invalidates the plan rather than being silently rewritten.
* **Let the wallet own execution.** The wallet simulates the exact plan, presents the simulated result, collects authorization, and submits — preserving step order (a plan may require atomic batching), following the plan's simulation-failure policy on reverts, and applying each step's bundled custom-error ABI when decoding failures. An agent should not add a second confirmation on top.

Prepared on-chain reads travel the same way, as `read_calls_reference` envelopes whose stored body is an exact batch-call argument object. The full contract is published as the server's `ekubo://docs/execution-plan` resource.

## A typical swap

1. Resolve the tokens by symbol or address, and show the user the chains and addresses chosen.
2. Convert the user's amount to base units without floating-point arithmetic.
3. Once the user has decided to swap, request quotes in a single call with the sender and slippage tolerance. Every available source is returned — the server does not pick one — and each option already carries the execution plan that executes it, so the quote the user compared is the quote that executes. Individual provider failures are reported separately without invalidating the quotes that succeeded.
4. Choose an option and hand its `execution_plan_reference` to the wallet unchanged. The wallet fetches and verifies the plan body, simulates it, presents the result, and submits after authorization.
5. Re-quote only after an expiry, a revert, or a change to the request — never to "refresh" a plan already in hand, which would replace the quote the user approved.

For "swap my entire balance" requests there is an extra step: read the exact on-chain balance first, rather than trusting a displayed number. And for a purely indicative "what would I get" comparison, omit the sender and slippage — quotes come back with no calldata attached.

## Notes

* Supported on EVM chains, including Robinhood Chain (chain ID **4663** — the L2, not the brokerage).
* The server is versioned and advertises `listChanged` for both tools and resources, so clients are notified when its surface changes.
* Underlying protocol data comes from the same public [Ekubo API](../reference/ekubo-api/README.md) and [Quoter API](../reference/quoter-api.md) documented here, so results agree with the interface and with your own integrations.

Questions or problems? Ask in the [Discord](https://discord.ekubo.org).
