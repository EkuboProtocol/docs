---
description: >-
  Resolve tokens, convert amounts to base units, and compare indicative EVM swap
  quotes from the Ekubo MCP server, then hand the chosen plan to a wallet
title: "Compare swap quotes with an AI agent"
---

This guide builds the read-only first half of an agent swap: resolve two tokens on one EVM chain, convert a human amount to base units, and compare the quotes every available source returns. It ends where execution would begin and describes that continuation without running it. Nothing here signs, submits, or needs a funded wallet.

It uses the public [Ekubo MCP server](/products/mcp-server/), which needs no API key. An agent connected to the server makes the same calls; the script below makes them directly so you can check the exact inputs and outputs.

## Scope

| Item       | Covered here                                                                                                                                                                                                                 |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Chains     | Same-chain swaps on the EVM chains the server indexes. The example uses Ethereum (chain ID 1). The quote tool takes EVM chain IDs only.                                                                                      |
| Sources    | Every source the server returns for the request. On 24 October 2026 that was Ekubo and 0x for same-chain swaps; cross-chain requests go to Across, LayerZero, and LI.FI instead.                                             |
| Server     | Observed on server version `0.53.2`, tool catalog revision `2026-10-21.legacy-route-removal`. The live catalog at [`https://mcp.ekubo.org/tools`](https://mcp.ekubo.org/tools) is authoritative where this page has drifted. |
| Quote kind | Indicative only: no `sender` and no `slippage_bps`, so no calldata is produced.                                                                                                                                              |

## Prerequisites

- Node.js 20 or later. The example was run with Node.js 22.23.4 in a fresh `node:22-slim` container.
- Outbound HTTPS to `mcp.ekubo.org`.
- No wallet, private key, RPC endpoint, or API key.

## Run the example

Create an empty directory and install the official MCP TypeScript client:

```sh
npm init -y
npm install @modelcontextprotocol/sdk@1.32.2
```

Save this as `compare-quotes.mjs`. It connects to the `ekubo` endpoint, which serves only Ekubo's core tools; the bundled `https://mcp.ekubo.org/mcp` endpoint accepts the same calls.

```js
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

const CHAIN_ID = 1;
const SELL = "ETH";
const BUY = "USDC";
const AMOUNT = "0.5";

const client = new Client({ name: "ekubo-quote-comparison", version: "1.0.0" });
await client.connect(
  new StreamableHTTPClientTransport(new URL("https://mcp.ekubo.org/mcp/ekubo")),
);

async function call(name, args) {
  const result = await client.callTool({ name, arguments: args });
  if (result.isError) throw new Error(`${name}: ${result.content?.[0]?.text}`);
  return result.structuredContent;
}

async function resolve(symbol) {
  const { tokens } = await call("list_tokens", {
    chain_id: CHAIN_ID,
    search: symbol,
    page_size: 20,
  });
  const token = tokens.find(
    (t) => t.symbol.toLowerCase() === symbol.toLowerCase(),
  );
  if (!token) throw new Error(`no exact ${symbol} on chain ${CHAIN_ID}`);
  return token;
}

function toBaseUnits(amount, decimals) {
  const [whole, fraction = ""] = amount.split(".");
  if (fraction.length > decimals) throw new Error("too many decimal places");
  return BigInt(whole + fraction.padEnd(decimals, "0")).toString();
}

function fromBaseUnits(value, decimals) {
  const digits = value.padStart(decimals + 1, "0");
  return `${digits.slice(0, -decimals)}.${digits.slice(-decimals)}`;
}

const sell = await resolve(SELL);
const buy = await resolve(BUY);
for (const t of [sell, buy]) {
  console.log(
    `${t.symbol.padEnd(5)} chain ${t.chain_id}  ${t.address}  decimals ${t.decimals}`,
  );
}

const amount = toBaseUnits(AMOUNT, sell.decimals);
console.log(`\nexact_input ${AMOUNT} ${sell.symbol} = ${amount} base units\n`);

const result = await call("get_quotes_with_plans", {
  chain_id: CHAIN_ID,
  token_in: sell.address,
  token_out: buy.address,
  quote_type: "exact_input",
  amount,
});

for (const { source, normalized: q, jurisdiction } of result.quotes) {
  console.log(
    [
      source.padEnd(6),
      `amount_out ${fromBaseUnits(q.amount_out, buy.decimals)} ${buy.symbol}`,
      `estimated_gas ${q.estimated_gas ?? "not reported"}`,
      `execution_hold ${jurisdiction.execution_hold}`,
    ].join("  "),
  );
}
console.log(
  "\nunavailable_sources",
  JSON.stringify(result.unavailable_sources),
);
console.log("comparison_complete", result.comparison.comparison_complete);
console.log(
  "execution_plans_included",
  result.execution.execution_plans_included,
);

await client.close();
```

Run it:

```sh
node compare-quotes.mjs
```

## Expected output

This is the output observed at 15:49 UTC on 24 October 2026. Token metadata should match exactly; the amounts and gas move with the market on every run.

```text
ETH   chain 1  0x0000000000000000000000000000000000000000  decimals 18
USDC  chain 1  0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48  decimals 6

exact_input 0.5 ETH = 500000000000000000 base units

ekubo   amount_out 1143.880660 USDC  estimated_gas 111459  execution_hold false
0x      amount_out 1147.935609 USDC  estimated_gas 246604  execution_hold false

unavailable_sources []
comparison_complete true
execution_plans_included false
```

In this run 0x quoted the larger output and the higher gas estimate. Which source quotes more depends on the pair, the size, and the block, so do not assume either way; read the numbers each time.

## What each step is guarding against

### Token identity

`list_tokens` matches a symbol prefix or suffix, so a search for `USDC` also returns tokens such as `SPUSDC` and `REUSDC`, and a search for `ETH` returns `cbETH` and `rETH`. The script accepts only an exact symbol match and takes the first one, because results are ordered by descending `visibility_priority`. Show the user the chosen chain ID and address before quoting, and look up an address the user supplied with `get_token` or `get_tokens` rather than by symbol.

A symbol does not identify a token across chains: USDC on Base is a different contract from USDC on Ethereum. Resolve each token on the chain you will quote on. On EVM chains the all-zero address denotes the chain's native token.

### Units

`amount` is an integer string in base units, so 0.5 ETH with 18 decimals is `500000000000000000`. Convert with string or integer arithmetic, never floating point: in JavaScript, `BigInt(1.1 * 10 ** 18)` is `1100000000000000128n`, not `1100000000000000000n`. Read `decimals` from the token record instead of assuming 18; USDC uses 6.

### Gross and net output

`amount_out` is each source's reported output before the gas the sender pays. A gross comparison is what the server reports in `comparison.comparison_basis` (`highest_calculated_amount_out`), and it is not the whole cost. To compare net outcomes, value each option as `amount_out` minus `estimated_gas × gas price` converted to the output token, using a current gas price from your own RPC.

That is only possible when a source reports gas. Both sources reported `estimated_gas` in the run above, but a source can return it as `null`; treat that as unknown, not as zero, and say so rather than ranking on half the data. A wallet simulation of the chosen plan gives a fresher gas estimate; only the transaction receipt establishes the gas actually used. For cross-chain options, LayerZero charges `native_fee` outside `amount_out`, so add it to that option's cost.

`price_impact` is reported by some sources and not others. It is a provider-computed figure, not a comparable cost, so it should not decide between sources on its own.

### Unavailable sources

If a provider fails, it is listed in `unavailable_sources` and the others still return. `comparison_complete` is then `false` and `retry_instruction` says what to do. Tell the user the comparison is incomplete instead of presenting the remaining quote as the best available.

### Jurisdiction metadata

Every quote carries a `jurisdiction` object. The script prints its `execution_hold` flag; when that flag is `true`, or `coverage` is `unknown`, the quote must not proceed to execution. The full set of conditions, including what the agent must establish from the user before any signature, is defined by the live [`get_quotes_with_plans` tool description](https://mcp.ekubo.org/tools?protocol=ekubo) and the server's `ekubo://docs/quoter-api` resource. Read them there; this page does not restate them.

## Continuing to execution

Execution is a separate, deliberate step, and this guide does not run it. When the user has decided to swap, the documented continuation is:

1. Establish the user's eligibility as the tool description requires, and stop if any quote carries an execution hold.
2. Bind the actual signing account first, then call `get_quotes_with_plans` once more with that account as `sender` and a `slippage_bps` sized by the rule in that parameter's live schema. Each option now carries `execution.execution_plan_reference`.
3. Pass the chosen option's `execution_plan_reference` to the wallet unchanged. The wallet fetches the plan body, verifies its integrity, simulates it, applies its policy, and asks for authorization.
4. Re-quote only after an expiry, a revert, or a change to the request. Re-quoting to refresh a plan you already hold replaces the quote the user approved.

The rules for that handoff are in [The execution plan boundary](/products/mcp-server/#the-execution-plan-boundary) and, authoritatively, in the server's `ekubo://docs/execution-plan` resource. You can read it with the same client:

```js
const { contents } = await client.readResource({
  uri: "ekubo://docs/execution-plan",
});
console.log(contents[0].text);
```

[Build a plan producer](/wallet/producers/) describes what the wallet does with the reference.

## Troubleshooting

| Symptom                                                       | Cause and fix                                                                                                                                                                                             |
| ------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `no exact XYZ on chain N`                                     | The symbol is not in the canonical list for that chain at the default visibility threshold. Look the token up by address with `get_token`, or pass a negative `min_visibility_priority` to `list_tokens`. |
| `amount must be a positive base-unit integer`                 | `amount` was passed in human units. Convert it to an integer string in base units first.                                                                                                                  |
| HTTP `429`                                                    | A rate limit was hit. Wait for the `Retry-After` seconds; `data.scope` names the budget. See [Rate limits](/products/mcp-server/#rate-limits).                                                            |
| `comparison_complete` is `false`                              | A provider failed. Read `unavailable_sources` and `retry_instruction`.                                                                                                                                    |
| `estimated_gas` is `null`                                     | That source did not report gas in its normalized quote. Its net cost is unknown from this response.                                                                                                       |
| `execution_plans_included` is `false`                         | Expected for an indicative request. Plans are only built when `sender` and `slippage_bps` are both supplied.                                                                                              |
| `SyntaxError: Cannot use import statement outside a module`   | Save the file with the `.mjs` extension, or set `"type": "module"` in `package.json`.                                                                                                                     |
| `ERR_PACKAGE_PATH_NOT_EXPORTED` or a missing transport export | A different major version of the SDK is installed. Install the exact version above.                                                                                                                       |

## Limitations

- Indicative quotes are not firm. They are recomputed on every call and are not reserved, and the planned quote returned later is a new quote.
- The server returns every source it obtained and selects none. It does not assess execution quality beyond the reported amounts.
- Only the sources the server queries are compared. A venue it does not call is not represented.
- An agent connected to the server sees the same tools, but its own model decides how to present the results. The checks above are what to verify in its answer.
