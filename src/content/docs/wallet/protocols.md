---
description: >-
  Which protocols Ekubo Wallet can transact with, why that coverage grows
  without a wallet update, and how any MCP server becomes compatible
title: "Supported protocols"
---

Ekubo Wallet does not implement protocols. It validates an exact execution plan, simulates it against the configured network, evaluates the active signing policy, presents any required native review, signs, and submits. The calldata itself comes from a _producer_: a Model Context Protocol server that reads live protocol state and returns an unsigned plan for the wallet to execute.

That separation is why the wallet's protocol coverage is not a property of the version you installed. Most of it lives in the public [Ekubo MCP server](/products/mcp-server/), which is deployed on its own schedule.

## What the hosted Ekubo server prepares today

| Protocol            | Actions                                                                                                                                                                                                                             |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Ekubo**           | Swaps, liquidity deposits, withdrawals, and earnings claims, pool initialization, DCA and TWAMM orders, [ve(3,3)](/products/ve33/) staking, voting, reallocation and fee claims, auctions, and [rewards](/products/rewards/) claims |
| **0x**              | Same-chain swap quotes, returned alongside Ekubo's for the same request so the two are compared before either is executed                                                                                                           |
| **Across**          | Any-to-any bridging, quoted alongside LayerZero and LI.FI whenever a swap's origin and destination chains differ                                                                                                                    |
| **LayerZero**       | Any-to-any transfers through the Value Transfer API, priced for an exact input amount, and tracked from the origin transaction through to delivery                                                                                  |
| **LI.FI**           | Any-to-any bridging priced in either direction, so an exact-output bridge is quoted twice, and tracked through to delivery                                                                                                          |
| **Aave V3**         | Supply, withdraw, borrow, repay, collateral toggles, and eMode categories on Ethereum, Base, Arbitrum, Optimism, Polygon, and Avalanche                                                                                             |
| **Morpho Vault V2** | Vault deposits, withdrawals, and redemptions on Ethereum and Base                                                                                                                                                                   |
| **Sky Savings**     | USDS and sUSDS deposits, withdrawals, and redemptions on Ethereum                                                                                                                                                                   |
| **Lido**            | ETH staking, wstETH wrapping and unwrapping, and withdrawal requests and claims on Ethereum                                                                                                                                         |
| **Merkl**           | Incentive reward claims, for campaigns on any protocol Merkl covers, on the 22 chains where the Distributor deployment has been verified                                                                                            |

More protocols are being added, so the live catalog is worth checking rather than this table: `https://mcp.ekubo.org/tools` returns the current tools, uncached, with the server version and catalog revision they came from.

The three bridge sources are compared rather than chosen for you: one cross-chain request returns whichever of them can serve it, each option already carrying the plan that executes it. A bridge is also the one plan whose successful origin transaction does not mean the funds have arrived, so a LayerZero or LI.FI transfer is tracked through to delivery on the destination chain before it is reported as finished.

For the non-Ekubo protocols the server prepares transactions but is deliberately not in the data path. Live market, vault, queue, and balance state is read by the agent from each protocol's own public API or from your wallet's RPC, and the wallet's simulation of the exact calls is what decides whether an action succeeds.

## Why a new protocol needs no wallet update

An execution plan is signer-neutral: an ordered list of unsigned calls, each with its chain, sender, target, value, and calldata, plus optional ABI material for decoding a revert. Nothing in it names a protocol. A plan that supplies Aave calldata and a plan that supplies Ekubo calldata are the same kind of document to the wallet, so a producer can start preparing a protocol the wallet has never heard of and the wallet executes it under the same rules.

The one thing a plan can require of the wallet is a named _capability_. The wallet rejects a plan listing any capability it does not implement, and today it implements exactly one — `atomic_batch`, the EIP-7702 batch. So protocol additions ship server-side and typically need no wallet release; only a plan that needed a new execution capability from the wallet itself would.

Your [signing policy](/wallet/policies/) is the other side of this. Policies match exact networks, targets, values, and calldata shapes, so a policy written for one protocol grants nothing over a newly supported one. A first action against a new protocol arrives as a native review, not as an automatic signature.

## Third-party producers

Nothing about the wallet's execution boundary is specific to Ekubo's server. Any MCP server that returns plans in the published shape works, and third parties are free to build them. [Build a plan producer](/wallet/producers/) is the full contract, with worked examples; what follows is its outline.

A compatible producer returns a reference rather than the plan itself:

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

The agent relays that object verbatim to the wallet, which fetches the body itself, recomputes the keccak256 digest over the exact bytes, checks the declared byte count, and refuses a mismatch. What a producer has to satisfy:

- **The stored body is a schema version `1` execution plan.** It carries `chain_id` and a matching `eip155:` CAIP-2 identifier, one sender that every step's `from` equals, and consecutively numbered `ordered_steps`. Unknown fields are rejected; producer-specific data belongs in the bounded `extensions` object, which the wallet ignores.
- **The URL is publicly fetchable HTTPS.** Admission is narrow: `https` on the default port to a public, resolvable host, with no credentials, fragments, redirects, or addresses in private or reserved ranges, and a hard size cap. A producer that has no public host can instead inline the body as a bounded `data:` URI, where the bytes are the reference.
- **Capabilities stay within what the wallet implements.** Omit `required_capabilities` unless the plan genuinely needs atomic batching.
- **A revert directive never says to retry identical calldata.** If a producer supplies a `simulation_failure_policy`, its `execution_reverted` and `simulation_setup_error` branches must direct the agent to re-prepare or to ask you, not to resend the plan that just failed.

Prepared on-chain reads travel the same way as `read_calls` artifacts whose body is an exact batch-call argument object, which lets a producer hand the wallet reads it wants performed against your RPC without proxying them.

The authoritative contract is published by the servers themselves rather than by this page: `https://mcp.ekubo.org/` returns the boundary and operational semantics as JSON, the hosted server's `ekubo://docs/execution-plan` resource documents the handoff in full, and the local wallet's own tool list describes the exact envelope its execution tools accept.

## What a producer never gets

Adding a producer is not a grant of authority, and the wallet treats every one of them the same way regardless of who operates it:

- It fetches and integrity-checks the plan body itself instead of trusting a relayed copy or a friendly summary of it.
- It simulates the exact calls against your configured network before anything is signed.
- It evaluates your active policy against the exact network, target, value, and calldata, and routes anything not explicitly allowed to native [owner review](/wallet/approvals/).
- It never hands over key material, an owner-authentication capability, or the ability to approve a request or install a policy.

What a producer does see is the tool arguments an agent sends it, which can include your address and intended action, and it can propose any calls it likes. Simulation, policy, and native review are what contain that — not the producer's good behavior. Add producers you are willing to have propose transactions to you, and read the exact values in the review rather than an agent's description of them. [Security and privacy](/wallet/security/) covers the complete boundary.
