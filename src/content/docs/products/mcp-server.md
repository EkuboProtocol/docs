---
description: >-
  Connect an AI agent to Ekubo: quotes, pool and position data, and unsigned
  execution plans over the Model Context Protocol
title: "MCP server"
---

Ekubo runs a public [Model Context Protocol](https://modelcontextprotocol.io/) server at **`https://mcp.ekubo.org/mcp`**. It gives AI agents first-class access to Ekubo — resolving tokens, quoting swaps, reading pools and positions, and building transactions — without scraping a web interface.

The server is **non-custodial and read-only with respect to keys**. It never holds funds, never signs, and never submits. Tools that produce a transaction return a reference to an unsigned _execution plan_; signing and submission happen in the user's own wallet tooling.

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

| Area                                         | Capabilities                                                                                                                                                                                                     |
| -------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tokens**                                   | Search the canonical token list by symbol, or look up exact chain/address pairs in batches of up to 1,000. Ordered by visibility priority so the preferred token wins ambiguous symbol matches.                  |
| **Swaps**                                    | One call returns every available quote — Ekubo and 0x for same-chain swaps, Across for cross-chain — each option already carrying the execution plan that executes it, so there is no separate preparation step. |
| **Pools**                                    | Read pool state and liquidity, list pool keys, derive pool IDs, decode pool configs, initialize pools, and correct a mispriced pool.                                                                             |
| **Liquidity positions**                      | List positions by owner, inspect a position, find candidate pools for a position, and prepare deposits, withdrawals, earnings claims, and transfers.                                                             |
| **DCA / TWAMM**                              | Place, collect, and stop orders, and execute virtual orders.                                                                                                                                                     |
| **[Ve33](/products/ve33/)**                  | Stake, vote, reallocate, extend, split, merge, increase, withdraw, reinvest, and claim fees — plus current allocations and a STONX allocation recommendation.                                                    |
| **[Auctions](/reference/contracts/evm-v3/)** | Create an auction, complete it, and collect creator proceeds.                                                                                                                                                    |
| **Rewards**                                  | List claimable [rewards](/products/rewards/) for an owner and prepare claims, including recovery fund claims; surface boosted-fee, incentive, and projected ve(3,3) opportunities ranked by APR.                 |
| **Utilities**                                | Revoke approvals, wrap and unwrap tokens, boost a pool manually, expand oracle capacity, unwrap old gEKUBO, and trigger revenue buybacks.                                                                        |

It also publishes **resources** that document its own conventions — the canonical agent workflow, the LP position workflow, the Ve33 workflow, quote semantics across providers, the execution-plan handoff, the data API's OpenAPI spec, and a chain-indexed directory of deployed contract addresses. Agents can read these directly rather than guessing at usage.

## The execution plan boundary

This is the part worth understanding before building on it.

Preparation tools never return "a transaction to send" loosely — and they do not return the plan inline either. Every executable preparation returns an `execution_plan_reference`: an artifact-reference envelope naming where the server stored the plan body, an integrity block (the keccak256 of the exact stored bytes plus their byte count), and a summary carrying the plan's `chain_id`, sender, and step count for sanity checks. The stored body — a signer-neutral, ordered sequence of unsigned calls — is the canonical boundary between the MCP server and whatever signs.

The rules that keep the boundary safe:

- **Relay the reference, not the body.** The agent passes the envelope unchanged to the wallet, which fetches the body over HTTPS, recomputes the integrity digest, checks the byte count, and refuses a mismatch. The agent in between never fetches, restates, or reconstructs the plan itself.
- **No timestamps travel in the envelope.** A plan's validity is expressed by the deadline inside its calldata and enforced by the wallet's simulation against current chain state. An expired reference simply 404s on fetch, and the fix is to re-run the preparation for fresh state and calldata.
- **Bind the sender first.** Choose the signing account before preparing, and pass that exact address. After preparation, the envelope summary's `chain_id` and sender must match the wallet's observed chain and account — a mismatch invalidates the plan rather than being silently rewritten.
- **Let the wallet own execution.** The wallet simulates the exact plan, presents the simulated result, collects authorization, and submits — preserving step order (a plan may require atomic batching), following the plan's simulation-failure policy on reverts, and applying each step's bundled custom-error ABI when decoding failures. An agent should not add a second confirmation on top.

Prepared on-chain reads travel the same way, as `read_calls_reference` envelopes whose stored body is an exact batch-call argument object. The full contract is published as the server's `ekubo://docs/execution-plan` resource.

## A typical swap

1. Resolve the tokens by symbol or address, and show the user the chains and addresses chosen.
2. Convert the user's amount to base units without floating-point arithmetic.
3. Once the user has decided to swap, request quotes in a single call with the sender and slippage tolerance. Every available source is returned — the server does not pick one — and each option already carries the execution plan that executes it, so the quote the user compared is the quote that executes. Individual provider failures are reported separately without invalidating the quotes that succeeded.
4. Choose an option and hand its `execution_plan_reference` to the wallet unchanged. The wallet fetches and verifies the plan body, simulates it, presents the result, and submits after authorization.
5. Re-quote only after an expiry, a revert, or a change to the request — never to "refresh" a plan already in hand, which would replace the quote the user approved.

For "swap my entire balance" requests there is an extra step: read the exact on-chain balance first, rather than trusting a displayed number. And for a purely indicative "what would I get" comparison, omit the sender and slippage — quotes come back with no calldata attached.

## Rate limits

The server is public and unauthenticated, so there is no API key to raise a quota against. Limits apply per caller, where a caller is one IPv4 address or one IPv6 /64. No fixed quota is guaranteed and the thresholds are not published, so an agent should react to what the server tells it rather than pace itself against a constant it has memorized.

The part worth designing around is that requests are not all counted the same. Four budgets run at once, and a rejection names the one you hit:

| Scope               | What it counts                                                                         |
| ------------------- | -------------------------------------------------------------------------------------- |
| `burst`             | Requests over a few seconds, across every endpoint                                     |
| `sustained`         | Requests over a minute, across every endpoint                                          |
| `tool_units`        | The weighted cost of tool calls over a minute                                          |
| `metered_providers` | Calls over a minute to the tools that buy quotes or recommendations from a third party |

`tool_units` is the one that catches integrators out. A tool call is charged by what it costs the server to answer, not as one request: `ekubo_derive_pool_id` hashes a struct locally and costs nothing at all, an ordinary token or pool read is the unit of measure, and a call that fans out across several upstream requests or buys a firm quote costs several times that. Two clients making an identical number of calls per minute can get very different answers, and the cheapest way to stay inside the budget is usually to ask for more per call rather than to call more often.

`metered_providers` is deliberately a separate and much smaller budget rather than a share of the same one, because those calls spend real money with third parties. Sitting comfortably inside `tool_units` does not buy you headroom for quotes.

### When you are limited

A rejection is an HTTP `429` carrying a `Retry-After` header in seconds. Honor that header rather than retrying on a fixed interval.

When the rejected request was a single identified JSON-RPC call, the body is a JSON-RPC error as well, so a client can attach the refusal to the call that caused it rather than to the connection:

```json
{
  "jsonrpc": "2.0",
  "id": "your-request-id",
  "error": {
    "code": -32029,
    "message": "Tool budget for this minute is exhausted...",
    "data": {
      "reason": "rate_limited",
      "scope": "tool_units",
      "retry_after_seconds": 60
    }
  }
}
```

`data.scope` is worth branching on, because the four scopes do not all mean the same thing. `burst` and `sustained` say you are asking too fast, and waiting is a complete fix. `tool_units` and `metered_providers` say the work you asked for was expensive, and waiting alone will not help if you resume the same pattern afterwards.

Enforcement is approximate, and it is measured close to where your request lands rather than globally. A batch of simultaneous requests can slip through where the same requests sent one after another would not, so treat a `200` as permission for that call rather than as evidence that you are inside the budget.

### Staying inside the budget

Batch instead of iterating. `ekubo_get_tokens` resolves up to 1,000 chain and address pairs in a single call and is charged once; the same thousand lookups issued individually are charged a thousand times. Where a tool offers a search or a filter, narrowing is far cheaper than paging the whole catalog and filtering client-side.

Reuse the quote you already hold. `ekubo_get_quotes_with_plans` buys firm quotes from providers, and each option it returns already carries the execution plan that executes it. Re-quoting to refresh a plan you already have spends the metered budget a second time and replaces the quote the user approved. Re-quote after an expiry, a revert, or a change to the request, not on a timer.

Respect the freshness windows. Protocol data is cached upstream, and pool state, pool keys, and tick liquidity do not change on every request. The server publishes the specific intervals as `polling_guidance` alongside the rate limit contract; polling faster than those windows spends budget without producing fresher data.

### Request size

Independently of the budgets, a single request may not exceed:

| Limit                          | Value         | Rejection |
| ------------------------------ | ------------- | --------- |
| Body size                      | 262,144 bytes | `413`     |
| JSON-RPC messages per request  | 20            | `400`     |
| Combined tool cost per request | 40 units      | `400`     |

The cost ceiling refuses rather than trims: an over-budget request is rejected outright instead of being quietly served at a discount. No single tool call reaches the ceiling on its own, so in practice it only ever asks you to split a batch — and JSON-RPC batching was removed from the protocol in revision 2025-06-18 in any case.

### Reading the contract at runtime

Rather than hard-coding any of this, a client can read it. `GET https://mcp.ekubo.org/` returns the current contract under `operational_semantics.rate_limit_contract`, covering every scope name, the response format, and the request-size limits, and `https://mcp.ekubo.org/llms.txt` carries the same summary in prose. Those are authoritative if this page ever drifts from them.

## Notes

- Supported on EVM chains, including Robinhood Chain (chain ID **4663** — the L2, not the brokerage).
- The server is versioned and advertises `listChanged` for both tools and resources, so clients are notified when its surface changes.
- Underlying protocol data comes from the same public [Ekubo API](/api/) and [Quoter API](/api/#quoter) documented here, so results agree with the interface and with your own integrations.

Questions or problems? Ask in the [Discord](https://discord.ekubo.org).
