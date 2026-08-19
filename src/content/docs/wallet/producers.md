---
description: >-
  Write an MCP server that prepares execution plans Ekubo Wallet will fetch,
  verify, simulate, and sign
title: "Build a plan producer"
---

Ekubo Wallet does not build transactions. It resolves an execution plan somebody else prepared, verifies it byte for byte, simulates the exact calls, evaluates the owner's [signing policy](/wallet/policies/), presents any required [review](/wallet/approvals/), signs, and submits. Everything upstream of that — reading protocol state, choosing a route, encoding calldata, deciding how many calls the action takes — belongs to a _producer_: a Model Context Protocol server the agent talks to alongside the wallet.

The [public Ekubo server](/products/mcp-server/) is one producer. Nothing about the boundary is specific to it, and this page is the contract a new one satisfies. Satisfy it and the wallet executes your plans without a wallet release, because a plan naming Aave calldata and a plan naming Ekubo calldata are the same kind of document to the wallet: it never learns what protocol it just used.

## The shape of the exchange

Three parties, and the middle one carries as little as possible:

1. The agent reads the wallet's inventory first, so it knows the account and chain before anything is prepared.
2. It calls your preparation tool with that exact sender and chain.
3. You build the plan, store its body somewhere fetchable, and return an `artifact_reference` envelope — not the plan.
4. The agent passes that envelope through to the wallet verbatim, as one object argument.
5. The wallet fetches the body itself, recomputes the digest, validates the plan, simulates it, checks policy, reviews if required, signs, and submits.

The agent never fetches, restates, paraphrases, or reconstructs your plan body, and you should say so in your tool descriptions. This is not only a safety property. A plan body is calldata, ABI fragments, and failure-policy prose: content only the wallet reads, and every byte of it that passes through the agent is paid for twice in model output. The envelope is a few hundred bytes regardless of how large the plan is.

## Return a reference, not a body

Every executable preparation result carries an envelope like this, conventionally under a key named `execution_plan_reference`:

```json
{
  "kind": "artifact_reference",
  "artifact_type": "execution_plan",
  "url": "https://plans.example.com/artifact/0f8c2b1e-…",
  "integrity": {
    "algorithm": "keccak256",
    "value": "0x5bec7df0e57e9f5c55461eb450a7aa567a42403f4b32ea55df8e5cff346e1ba5"
  },
  "bytes": 1632,
  "instruction": "Pass this reference object unchanged as the wallet's reference argument."
}
```

| Field           | Requirement                                                                                                                                         |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `kind`          | Exactly `artifact_reference`.                                                                                                                       |
| `artifact_type` | `execution_plan`, `read_calls`, or `token_list`. The wallet rejects a reference whose type is not the one the tool being called accepts.            |
| `url`           | A public `https` URL, or a bounded `data:application/json` URI carrying the body inline.                                                            |
| `integrity`     | `algorithm` must be `keccak256`; `value` is the 32-byte digest of the exact bytes served. The integrity object is parsed strictly: no extra fields. |
| `bytes`         | The exact byte length of the stored body. A body of any other length is refused before it is parsed.                                                |
| `instruction`   | Optional prose the agent reads. Use it to say "pass this through unchanged" and "a 404 means re-run this tool".                                     |

`integrity` and `bytes` are **required** whenever the body travels over the network. A `data:` URI is the exception: there the bytes _are_ the reference, so both are verified only if you supply them.

The envelope tolerates additive fields, so a future producer can enrich it without stranding wallets already deployed. Do not rely on that for anything load-bearing: the wallet acts only on the fields above.

### Nothing about time travels in the envelope

There is no `expires_at`, and you should not invent one. A plan's semantic validity is expressed by the deadline inside its own calldata and enforced by the wallet's simulation against current chain state, never by comparing two clocks. Storage expiry surfaces as an ordinary `404` on fetch, which the wallet reports as "expired or never existed, re-run the producer's preparation tool". Keep bodies fetchable long enough for a human to read a review — minutes, not seconds — and let a stale reference fail loudly rather than serving a plan built against state that has moved.

### Where the body may live

The wallet's plan fetch is the only outbound request it makes that is not a configured chain RPC, so admission is deliberately narrow. A URL that fails any of these is refused before a connection is opened:

- `https` only, on the default port, with no credentials in the authority and no fragment.
- A public, resolvable host. Names ending in `.local`, `.internal`, `.localhost`, `.onion`, or `.home.arpa` are refused, as is any host resolving to a private or reserved address.
- No redirects. The wallet does not follow one, so serve the body at the URL you published.
- A hard body cap of 16 MiB for plans and read bundles, enforced while streaming.

Standard HTTP content encodings are decompressed first, and both `integrity.value` and `bytes` describe those decompressed bytes rather than the wire encoding. Serve the same bytes you hashed.

If you have no public host, or you are still developing, the `data:` alternative removes the hosting requirement entirely:

```
data:application/json;base64,eyJzY2hlbWFfdmVyc2lvbiI6IjEiLC…
```

Media type must be `application/json`; `;base64` and a `charset=` parameter are the only accepted parameters. Nothing touches the network, and the reference is bounded by the same body cap. This is the shortest path from a new server to a real signature, and it is a legitimate production shape for a small plan.

## The execution plan

The stored body is one signer-neutral, ordered transaction sequence. Parsing is strict on both sides: unknown fields anywhere in the plan are a rejection, not a warning. The only place producer-specific data belongs is the `extensions` bag.

| Field                       | Required | Meaning                                                                             |
| --------------------------- | -------- | ----------------------------------------------------------------------------------- |
| `schema_version`            | yes      | The string `"1"`. Not a number.                                                     |
| `chain_id`                  | yes      | Canonical unsigned decimal string. Not hex.                                         |
| `caip2_chain_id`            | yes      | Exactly `eip155:` followed by the same `chain_id`. A mismatch is rejected.          |
| `sender`                    | yes      | The one account that signs every step.                                              |
| `ordered_steps`             | yes      | 1 to 4,096 steps, one-indexed and consecutive.                                      |
| `required_capabilities`     | no       | Behaviors the wallet must implement to execute this plan. Omit unless you need one. |
| `extensions`                | no       | An object the wallet ignores, bounded at 64 KiB serialized.                         |
| `simulation_failure_policy` | no       | What the agent should do about each class of simulation failure.                    |

Each step is `step`, `kind`, `transaction`, and an optional `revert_decode`. The transaction carries `chain_id`, `from`, `to`, `data`, `value`, and an optional `gas`.

The wallet checks all of the following before it will simulate anything:

- **Quantities are canonical decimal strings, not hex.** `"0"`, or a digit string with no leading zero, fitting in a `uint256`. That covers `chain_id`, `value`, and `gas`. A JSON number is rejected, and so is `"0x0"`.
- **`data` is `0x`-prefixed, even-length hex**, possibly just `"0x"`.
- **Steps are one-indexed and consecutive.** Step `n` must be at array position `n - 1`.
- **Every step's `chain_id` equals the plan's**, and every step's `from` equals the plan's `sender`. A plan is single-chain and single-signer by construction; a cross-chain action is two plans.

Emit addresses checksummed. The wallet parses either case, but a producer that normalizes on the way out catches its own transcription errors, and the Ekubo server's producer-side validator refuses anything else.

### Step kinds

`kind` is not decoration. The wallet shows the owner why a step they did not ask for is in the plan, and it reads that reason off the kind.

| Kind                            | What it says                                                |
| ------------------------------- | ----------------------------------------------------------- |
| `approval`                      | Grants a spending allowance the next call needs.            |
| `execution`                     | Does the work the user asked for.                           |
| `allowance_cleanup`             | Takes an allowance back afterwards.                         |
| `signature_dependent_execution` | Spends a signature approved earlier.                        |
| `other`                         | Anything else, and the review says nothing useful about it. |

Label the approval you added as an `approval` rather than folding it into `execution`. It is the difference between a review that explains itself and one that shows the owner two opaque calls.

### Capabilities

`required_capabilities` names behavior the wallet must implement, and a wallet that does not implement a listed capability rejects the plan outright rather than adapting it. Today the wallet implements exactly one, `atomic_batch`, so anything else you emit produces plans no deployed wallet accepts.

Multi-step plans are executed as one atomic EIP-7702 batch regardless, so declare `atomic_batch` when the action is only correct as a batch — not on every multi-step plan out of caution. Names are bounded at 64 printable ASCII characters and at most 32 entries.

### Revert decoding

An execution step may carry a `revert_decode` plan so the wallet can decode a custom error locally. In an execution plan there is exactly one accepted shape:

```json
{
  "kind": "error_result",
  "abi": [
    {
      "type": "error",
      "name": "MinimumOutputNotMet",
      "inputs": [
        { "name": "minimum", "type": "uint256" },
        { "name": "actual", "type": "uint256" }
      ]
    }
  ],
  "required": false
}
```

The `abi` array holds 1 to 128 entries, at most 64 KiB serialized, must parse as a JSON ABI, and must contain at least one `error`. Supply the target contract's canonical custom-error ABI and nothing else.

This is worth stating flatly because it is the most common way a producer's first plan is rejected: **the decode shapes available to prepared reads are not available here.** `function_result`, `abi_parameters`, `multicall3`, `function_result_bytes_array`, and `semantic_value` decode _read results_. An execution plan's `revert_decode` accepts `error_result` and nothing else. The two surfaces are disjoint.

The wallet owns any batch-wrapper decoding. It unwraps its own execution-layer errors, keeps both the outer and the innermost revert bytes, and applies your step ABI to the innermost. You do not need to know or describe the wrapper.

### Simulation failure policy

If you supply `simulation_failure_policy`, all three branches are required, and each is an `action` plus a 1 to 2,000 character `instruction`.

| Branch                   | Meaning                                                     | Allowed actions                 |
| ------------------------ | ----------------------------------------------------------- | ------------------------------- |
| `rpc_error`              | The simulation infrastructure failed, not the calls.        | any                             |
| `execution_reverted`     | The exact calldata reverted against current state.          | `reprepare_plan`, `user_review` |
| `simulation_setup_error` | No trustworthy simulation environment could be established. | `reprepare_plan`, `user_review` |

`retry_same_plan` on either of the last two is a validation failure, not a preference the wallet overrules. Calldata that reverted against current state reverts again; a directive that says otherwise is a producer telling an agent to burn gas in a loop. Swap and bridge reverts, slippage included, always mean re-prepare against fresh state.

### Caps

The limits are part of the contract, and the wallet enforces them on your input:

| Limit                       | Value                 |
| --------------------------- | --------------------- |
| Steps per plan              | 1 to 4,096            |
| Total calldata across steps | 8 MiB                 |
| Serialized plan             | 16 MiB                |
| `extensions` serialized     | 64 KiB                |
| `required_capabilities`     | 32 entries            |
| Revert-decode ABI           | 128 entries, 64 KiB   |
| Failure-policy instruction  | 1 to 2,000 characters |

## A complete example

The body a producer stores for a two-step swap, an approval followed by the swap itself:

```json
{
  "schema_version": "1",
  "chain_id": "1",
  "caip2_chain_id": "eip155:1",
  "sender": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  "ordered_steps": [
    {
      "step": 1,
      "kind": "approval",
      "transaction": {
        "chain_id": "1",
        "from": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        "to": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        "data": "0x095ea7b30000000000000000000000002222222222222222222222222222222222222222000000000000000000000000000000000000000000000000000000000ee6b280",
        "value": "0"
      }
    },
    {
      "step": 2,
      "kind": "execution",
      "transaction": {
        "chain_id": "1",
        "from": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        "to": "0x2222222222222222222222222222222222222222",
        "data": "0x9d9892cd000000000000000000000000000000000000000000000000000000000ee6b28000000000000000000000000000000000000000000000000001626218b45860000000000000000000000000000000000000000000000000000000000068a4f0c0",
        "value": "0"
      },
      "revert_decode": {
        "kind": "error_result",
        "abi": [
          {
            "type": "error",
            "name": "MinimumOutputNotMet",
            "inputs": [
              { "name": "minimum", "type": "uint256" },
              { "name": "actual", "type": "uint256" }
            ]
          }
        ]
      }
    }
  ],
  "simulation_failure_policy": {
    "rpc_error": {
      "action": "retry_same_plan",
      "instruction": "Simulation infrastructure failed rather than the calls themselves. Retry the identical plan once the RPC recovers."
    },
    "execution_reverted": {
      "action": "reprepare_plan",
      "instruction": "The exact calldata reverted against current state. Return to the preparation tool for fresh state and calldata; do not resend these bytes."
    },
    "simulation_setup_error": {
      "action": "user_review",
      "instruction": "The wallet could not establish a trustworthy simulation environment. Check the selected wallet, network, and RPC chain before continuing."
    }
  }
}
```

The addresses and calldata above are illustrative. The `integrity.value` and `bytes` shown in the earlier envelope are the real keccak256 digest and byte length of this body serialized without whitespace, which is what a wallet would recompute: the digest covers the exact bytes you serve, so hash the string you store rather than a pretty-printed copy of it.

## Prepared reads

A producer that wants live chain state read through the owner's own RPC — rather than proxying it, holding their credentials, or making the agent assemble calldata — returns a `read_calls` artifact. Same envelope, and the stored body is the wallet's batch-read argument object exactly, with nothing added:

```json
{
  "chain_id": "1",
  "block_parameter": "latest",
  "calls": [
    {
      "id": "usdc_balance",
      "to": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      "data": "0x70a08231000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      "decode": {
        "kind": "function_result",
        "abi": [
          {
            "type": "function",
            "name": "balanceOf",
            "stateMutability": "view",
            "inputs": [{ "name": "account", "type": "address" }],
            "outputs": [{ "name": "", "type": "uint256" }]
          }
        ],
        "function_name": "balanceOf",
        "required": true
      },
      "include_raw": true
    }
  ]
}
```

`chain_id` is a positive decimal string, `block_parameter` defaults to `latest` and otherwise takes `pending`, `safe`, `finalized`, `earliest`, or a hex block number, `from` is optional, and `calls` holds 1 to 4,096 entries. The body is parsed with unknown fields rejected, which is the point: a fetched bundle cannot smuggle in a field the tool call itself did not declare.

A `decode` plan on a call is optional and may be `function_result`, `abi_parameters`, `multicall3`, `function_result_bytes_array`, or `semantic_value`. Keep `include_raw` true. Decoding is a convenience, and the raw return bytes are the thing that is actually authoritative — a producer that discards them has no recourse when a decode fails.

Two rules that are easy to get wrong. Do not ask the wallet to send you the decoded result for authoritative interpretation; supply the ABI, let the decode happen locally, and accept back only what you need. And where a read must be atomic with respect to a state-changing call — a virtual-order execution followed by the position read that depends on it — keep both in a single batched `eth_call` rather than splitting them, and never let those calls be broadcast.

A third artifact type, `token_list`, carries curated token metadata so a wallet can label transactions without the agent re-emitting thousands of rows. It travels through the identical envelope.

## What the wallet does next, and what you must not assume

Handing over a reference starts a pipeline you do not control and cannot shorten:

The wallet fetches and integrity-checks the body, refusing a mismatch. It validates the plan against everything above. It refuses a plan whose `chain_id` or `sender` disagrees with the connected chain and account — which is why the sender must be bound _before_ preparation, from the wallet's own inventory, and why a mismatch means re-preparing rather than rewriting the sender or switching networks. It simulates the exact calls against real chain state. It evaluates the owner's current policy against the exact network, target, value, and calldata. Anything not explicitly allowed goes to native review; anything a deny rule matches fails without ever queueing.

Some consequences worth designing around:

- **A simulation is not an authorization.** The handle the wallet returns for a simulated plan is a short-lived pointer to those exact bytes. Sending it repeats simulation, transaction preparation, and the policy evaluation from scratch.
- **The owner's approval binds the bytes that broadcast.** It covers the plan version, chain, sender, and each step's number, kind, and transaction. It deliberately does not cover `gas`, `revert_decode`, `simulation_failure_policy`, `required_capabilities`, or `extensions`, none of which change what executes.
- **Do not ask for a second confirmation.** Prompting the user in the agent before invoking the wallet duplicates the wallet's own authorization flow and trains people to click through it.
- **A new protocol is not a new permission.** Policies match exact networks, targets, values, and calldata shapes, so a first action against a protocol you just added arrives as a review. That is the design, not a misconfiguration.
- **You never receive anything.** No key material, no owner authentication, no ability to approve a request or install a policy. What you do see is the tool arguments the agent sends, which can include the owner's address and intended action.

Simulation, policy, and native review are what contain a producer. Your good behavior is not the mechanism, which is exactly why a third party can build one.

## Writing the tool descriptions

The agent between you and the wallet is a model reading two servers' tool descriptions at once, and most integration failures are description failures rather than schema failures. Four things are worth saying explicitly in yours:

Bind the sender first: instruct the agent to read the wallet's account and network before calling your preparation tool, not after. Relay the envelope whole: say that it is an object argument, never a JSON-encoded string, and that renaming or reconstructing it is wrong. Do not re-prepare a plan you already hold: an agent that "refreshes" a plan before signing discards the one the user compared and, if your preparation costs a metered quote, pays for it twice. And name the 404: a fetch failure means the reference expired and the fix is to call you again, never to rebuild the plan from a description.

## Checklist

Before pointing a wallet at a new producer:

- Plan bodies validate against every rule above, including the ones you think cannot fire. Validate on the way out, fail closed, and never emit a plan you would not accept.
- Bodies are served over public HTTPS with no redirect, or inlined as bounded `data:` URIs.
- `integrity.value` is the keccak256 of the exact served bytes, and `bytes` is their exact length.
- `revert_decode` uses `error_result` only.
- No `simulation_failure_policy` branch tells an agent to resend calldata that reverted.
- `required_capabilities` is omitted unless the plan genuinely needs `atomic_batch`.
- Producer-specific data lives in `extensions`, under 64 KiB, and nothing depends on the wallet reading it.

## The authoritative contract

This page describes the boundary; the servers publish it. `https://mcp.ekubo.org/` returns the current boundary and operational semantics as JSON, its `ekubo://docs/execution-plan` resource documents the handoff in full, and the wallet's own MCP tool descriptions and argument schemas are the exact surface its execution tools accept. Where any of those disagree with this page, they are correct and the page is stale.

[Supported protocols](/wallet/protocols/) covers what the hosted Ekubo producer prepares today and why coverage grows without a wallet release. [Use Ekubo Wallet with AI agents](/wallet/agents/) is the same boundary from the agent's side, and [Security and privacy](/wallet/security/) states the complete local boundary.
