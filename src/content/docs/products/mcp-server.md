---
description: >-
  Connect an AI agent to Ekubo: quotes, pool and position data, and unsigned
  execution plans for Ekubo, Aave, Morpho, Sky, Lido, and Merkl over the Model
  Context Protocol
title: "MCP server"
---

Ekubo runs a public [Model Context Protocol](https://modelcontextprotocol.io/) server at **`https://mcp.ekubo.org/mcp`**. It gives AI agents first-class access to Ekubo — resolving tokens, quoting swaps, reading pools and positions, and building transactions — without scraping a web interface.

Because an execution plan is signer-neutral calldata rather than an Ekubo-specific document, the server's coverage does not stop at Ekubo: it also prepares Aave V3, Morpho Vault V2, Sky Savings, Lido, and Merkl actions, and quotes swaps from 0x and bridges from Across, LayerZero, and LI.FI alongside Ekubo's own.

The server is **non-custodial and read-only with respect to keys**. It never holds funds, never signs, and never submits. Tools that produce a transaction return a reference to an unsigned _execution plan_; signing and submission happen in the user's own wallet tooling.

## Connecting

The server speaks Streamable HTTP and requires no authentication.

### Claude Desktop

Claude Desktop manages remote MCP servers as account-level custom connectors. Do not add the hosted Ekubo server to `claude_desktop_config.json`; that file is for local stdio servers.

1. In Claude Desktop, open **Customize → Connectors**.
2. Click **+**, then select **Add custom connector**.
3. Name the connector **Ekubo**.
4. Enter **`https://mcp.ekubo.org/mcp`** as its remote MCP server URL.
5. Click **Add**, then enable Ekubo for the conversations where you want to use it.

On Team and Enterprise plans, an Owner or Primary Owner must first add the custom connector under **Organization settings → Connectors**. Members can then connect and enable it from **Customize → Connectors**. See [Anthropic's custom connector guide](https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp) for the current account and organization flows.

### Grok Build

Ekubo Wallet detects Grok Build and can install both its local wallet bridge and
this hosted companion into `~/.grok/config.toml`. To configure only the hosted
server manually, use Grok Build's native TOML shape:

```toml
[mcp_servers.ekubo]
url = "https://mcp.ekubo.org/mcp"
```

### Other MCP clients

For clients that accept remote MCP servers in a local configuration file, add:

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

Most clients also accept it from the command line. For example, Claude Code uses `claude mcp add --transport http ekubo https://mcp.ekubo.org/mcp`.

## What it can do

More than seventy tools, grouped by what you're trying to accomplish. The catalog grows on its own schedule, so `https://mcp.ekubo.org/tools` — which returns the live list along with the server version and catalog revision it came from — is authoritative wherever this page has drifted.

| Area                                         | Capabilities                                                                                                                                                                                                                           |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tokens**                                   | Search the canonical token list by symbol, or look up exact chain/address pairs in batches of up to 1,000. Ordered by visibility priority so the preferred token wins ambiguous symbol matches.                                        |
| **Swaps**                                    | One call returns every available quote — Ekubo and 0x for same-chain swaps, Across, LayerZero, and LI.FI for cross-chain — each option already carrying the execution plan that executes it, so there is no separate preparation step. |
| **Pools**                                    | Read pool state and liquidity, list pool keys, derive pool IDs, decode pool configs, initialize pools, and correct a mispriced pool.                                                                                                   |
| **Liquidity positions**                      | List positions by owner, inspect a position, find candidate pools for a position, and prepare deposits, withdrawals, earnings claims, and transfers.                                                                                   |
| **DCA / TWAMM**                              | Place, collect, and stop orders, and execute virtual orders.                                                                                                                                                                           |
| **[Ve33](/products/ve33/)**                  | Stake, vote, reallocate, extend, split, merge, increase, withdraw, reinvest, and claim fees — plus current allocations and a STONX allocation recommendation.                                                                          |
| **[Auctions](/reference/contracts/evm-v3/)** | Create an auction, complete it, and collect creator proceeds.                                                                                                                                                                          |
| **Rewards**                                  | List claimable Ekubo [rewards](/products/rewards/) for an owner and prepare claims, including recovery fund claims; surface boosted-fee, incentive, and projected ve(3,3) opportunities ranked by APR.                                 |
| **Other protocols**                          | Aave V3, Morpho Vault V2, Sky Savings, Lido, and Merkl — see [Protocols beyond Ekubo](#protocols-beyond-ekubo).                                                                                                                        |
| **Transfers**                                | Prepare one ordered plan of 1 to 4,096 native, ERC-20, ERC-721, and ERC-1155 transfers on a chain, mixed freely.                                                                                                                       |
| **Utilities**                                | Revoke approvals, wrap and unwrap tokens, boost a pool manually, expand oracle capacity, unwrap old gEKUBO, trigger revenue buybacks, and export the token list to a wallet by reference.                                              |

It also publishes **resources** that document its own conventions — the canonical agent workflow, the LP position workflow, the Ve33 workflow, quote semantics across providers, the execution-plan handoff, the data API's OpenAPI spec, and a chain-indexed directory of deployed contract addresses. Agents can read these directly rather than guessing at usage.

Alongside those it publishes **skills** — `ekubo://skills/use-morpho`, `ekubo://skills/use-sky`, `ekubo://skills/use-lido`, and `ekubo://skills/use-merkl`, each with a `references/discovery.md` child naming the official endpoints and reads. They are also plain files over HTTPS, at `https://mcp.ekubo.org/skills/use-merkl/SKILL.md` and its siblings, so a client that does not speak MCP resources can still load them.

## Protocols beyond Ekubo

For Aave V3, Morpho Vault V2, Sky Savings, Lido, and Merkl the server prepares transactions but is deliberately **not in the data path**. It holds a fixed, locally maintained deployment catalog — the addresses and the chains they were verified on — and returns unsigned calls against it. Live market, vault, queue, reward, and balance state is read by the agent from each protocol's own public API or through your wallet's RPC, never proxied, cached, or replayed by this server. What decides whether an action succeeds is the wallet's simulation of the exact calls.

[Supported protocols](/wallet/protocols/) lists the actions and chains for each.

### Merkl reward claims

[Merkl](https://merkl.xyz/) distributes incentive campaigns for hundreds of protocols. Rewards accrue off chain, are published as a Merkle root to a Distributor contract, and are claimed against a proof — so a claim's inputs necessarily come from Merkl's own API rather than from a chain.

The agent fetches them directly, from `https://api.merkl.xyz/v4/users/{address}/rewards/summary`, which is public and needs no key. What makes that safe is not trust in the response. `prepare_merkl_claim` folds every supplied proof into the Merkle root it implies, refuses a batch whose proofs fold to more than one root, and returns a read bundle asking the wallet for the root the chain is currently enforcing along with each already-claimed total and any claim-recipient override. A proof for a rotated tree, or for one still inside its dispute period, fails before anything is signed. Neither the server nor the wallet has to believe Merkl.

Three properties of Merkl's data are worth stating, because getting them wrong misreports what a user is owed:

- **`amount` is cumulative, not a delta.** The Distributor transfers `amount` minus what that address already claimed for that token, so the claimable figure is `amount - claimed`. Presenting `amount` overstates it, sometimes by everything already collected.
- **`pending` is not claimable.** It is earned but not yet in any published root, and adding it to `amount` double-counts.
- **Claiming for yourself needs no authorization.** Anyone may call `claim()` for a user and the tokens still go to that user, so enabling Merkl's autoclaim operator delegates gas and timing rather than custody.

`get_merkl_deployment` returns the Distributor address and the chains preparation is allowed on. Merkl lists 67 chains; the server pins the subset that answered `getMerkleRoot()` with a live root at that address, so an unverified chain is refused rather than served a plan nobody checked — ZKsync Era, which has no code at the address the other chains share, is the reason that check exists. One claim covers up to 32 reward tokens on a single chain.

This is distinct from `prepare_rewards_claim`, which claims Ekubo's own [incentive drops](/products/rewards/).

## The execution plan boundary

This is the part worth understanding before building on it.

Preparation tools never return "a transaction to send" loosely — and they do not return the plan inline either. Every executable preparation returns an `execution_plan_reference`: an artifact-reference envelope naming where the server stored the plan body, an integrity block (the keccak256 of the exact stored bytes plus their byte count), and a summary carrying the plan's `chain_id`, sender, and step count for sanity checks. The stored body — a signer-neutral, ordered sequence of unsigned calls — is the canonical boundary between the MCP server and whatever signs.

The rules that keep the boundary safe:

- **Relay the reference, not the body.** The agent passes the envelope unchanged to the wallet, which fetches the body over HTTPS, recomputes the integrity digest, checks the byte count, and refuses a mismatch. The agent in between never fetches, restates, or reconstructs the plan itself.
- **No timestamps travel in the envelope.** A plan's validity is expressed by the deadline inside its calldata and enforced by the wallet's simulation against current chain state. An expired reference simply 404s on fetch, and the fix is to re-run the preparation for fresh state and calldata.
- **Bind the sender first.** Choose the signing account before preparing, and pass that exact address. After preparation, the envelope summary's `chain_id` and sender must match the wallet's observed chain and account — a mismatch invalidates the plan rather than being silently rewritten.
- **Let the wallet own execution.** Before signing, the wallet freshly validates the exact plan, simulates current chain state, prepares the transaction, and evaluates its current policy. It then presents any required review and submits — preserving step order (a plan may require atomic batching), following the plan's simulation-failure policy on reverts, and applying each step's bundled custom-error ABI when decoding failures. Simulation IDs and previews are short-lived handles, not durable authorization. An agent should not add a second confirmation on top.

Prepared on-chain reads travel the same way, as `read_calls_reference` envelopes whose stored body is an exact batch-call argument object. The full contract is published as the server's `ekubo://docs/execution-plan` resource.

## A typical swap

1. Resolve the tokens by symbol or address, and show the user the chains and addresses chosen.
2. Convert the user's amount to base units without floating-point arithmetic.
3. Once the user has decided to swap, request quotes in a single call with the sender and slippage tolerance. Every available source is returned — the server does not pick one — and each option already carries the execution plan that executes it, so the quote the user compared is the quote that executes. Individual provider failures are reported separately without invalidating the quotes that succeeded.
4. Choose an option and hand its `execution_plan_reference` to the wallet unchanged. The wallet fetches and verifies the plan body, then freshly simulates, prepares, and checks current policy before any signature; it presents required review and submits after authorization.
5. Re-quote only after an expiry, a revert, or a change to the request — never to "refresh" a plan already in hand, which would replace the quote the user approved.

For "swap my entire balance" requests there is an extra step: read the exact on-chain balance first, rather than trusting a displayed number. And for a purely indicative "what would I get" comparison, omit the sender and slippage — quotes come back with no calldata attached.

## Cross-chain transfers

When a request's destination chain differs from its origin, the same `get_quotes_with_plans` call goes out to three bridges instead of two same-chain aggregators: [Across](https://across.to/), [LayerZero](https://layerzero.network/)'s Value Transfer API, and [LI.FI](https://li.fi/). They come back as ordinary quote options, compared exactly the way an Ekubo quote is compared against a 0x one, and the server picks none of them. A provider that cannot serve the request says so in `unavailable_sources` without costing the others their quote.

They do not all price the same question. LayerZero prices an exact source amount only, so an exact-output bridge — "leave me with exactly 1,000 USDC on Arbitrum" — reports `unsupported_quote_type` for LayerZero and is served by Across and LI.FI, which price both directions.

The part worth building around is what happens after the plan is signed. A bridge is the one execution plan whose successful origin receipt does not mean the user has their funds, so a LayerZero or LI.FI option is not finished when the origin transaction confirms. `get_value_transfer_status` reports where the transfer has reached, keyed by that option's `source`:

| Source      | Lookup key                                               |
| ----------- | -------------------------------------------------------- |
| `layerzero` | The option's `provider_quote_id`, plus the origin hash   |
| `lifi`      | The origin transaction hash — a quote id is not accepted |

Poll it every fifteen to thirty seconds while `settled` is false and stop as soon as it is true; transfers settle in minutes, and the call draws on the same metered budget as a quote. A status of `UNKNOWN` or `NOT_FOUND` in the first moments after submission means the transfer has not been indexed yet, not that it was lost. On a settled LI.FI transfer, read `substatus` before reporting delivery: `REFUNDED` and `PARTIAL` are both filed under status `DONE`, and only one of those means the money arrived.

Across transfers execute the same way but are not tracked by this tool.

## Jurisdiction restrictions

Some assets may not be traded from some countries. The Ekubo interface disables its action buttons for those; this server has no interface to disable, so it refuses to produce the execution plan at all. The restriction data mirrors the interface's, and today covers the tokenized equities on Robinhood Chain.

The country comes from the connecting IP as Cloudflare resolves it, the same source the interface reads, so a caller cannot supply or override it. A refusal is an ordinary tool error with code `restricted_jurisdiction` naming the offending assets, and it is raised before any upstream quote is bought.

What is gated is acquiring or disposing of a restricted asset: quoting a swap, placing a TWAMM order, depositing liquidity, creating an auction, expanding oracle capacity, correcting a pool price, and the swap phase of a ve(3,3) reinvestment. **Exits are never gated** — withdrawing liquidity, collecting fees or proceeds, transferring a position, and revoking approvals stay available to everyone, as they do in the interface. Discovery is untouched: restricted assets are still listed and priced.

An unresolved country fails closed, but only for assets that are restricted somewhere; it never blocks trading generally. A request arriving over Tor counts as unresolved rather than as a country code that can never match.

## Rate limits

The server is public and unauthenticated, so there is no API key to raise a quota against. Limits apply per caller, where a caller is one IPv4 address or one IPv6 /64. No fixed quota is guaranteed and the thresholds are not published, so an agent should react to what the server tells it rather than pace itself against a constant it has memorized.

The part worth designing around is that requests are not all counted the same. Four budgets run at once, and a rejection names the one you hit:

| Scope               | What it counts                                                                         |
| ------------------- | -------------------------------------------------------------------------------------- |
| `burst`             | Requests over a few seconds, across every endpoint                                     |
| `sustained`         | Requests over a minute, across every endpoint                                          |
| `tool_units`        | The weighted cost of tool calls over a minute                                          |
| `metered_providers` | Calls over a minute to the tools that buy quotes or recommendations from a third party |

`tool_units` is the one that catches integrators out. A tool call is charged by what it costs the server to answer, not as one request: `derive_pool_id` hashes a struct locally and costs nothing at all, an ordinary token or pool read is the unit of measure, and a call that fans out across several upstream requests or buys a firm quote costs several times that. Two clients making an identical number of calls per minute can get very different answers, and the cheapest way to stay inside the budget is usually to ask for more per call rather than to call more often.

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

Batch instead of iterating. `get_tokens` resolves up to 1,000 chain and address pairs in a single call and is charged once; the same thousand lookups issued individually are charged a thousand times. Where a tool offers a search or a filter, narrowing is far cheaper than paging the whole catalog and filtering client-side.

Reuse the quote you already hold. `get_quotes_with_plans` buys firm quotes from providers, and each option it returns already carries the execution plan that executes it. Re-quoting to refresh a plan you already have spends the metered budget a second time and replaces the quote the user approved. Re-quote after an expiry, a revert, or a change to the request, not on a timer.

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
