---
description: >-
  The gas-optimized router used for Ekubo swaps on EVM chains, and the
  TypeScript SDK that encodes routes for it
---

# Yul Router

The [Yul Router](https://github.com/EkuboProtocol/yul-router) is a gas-focused router written in Yul that executes Ekubo swaps on EVM chains. It is how swaps are executed in production today: the [interface](https://ekubo.org) encodes routes from [Quoter API](../reference/quoter-api.md) results and sends them to the router.

The router is deployed deterministically at the same address on every supported network (currently Ethereum, Base, Arbitrum, and Robinhood Chain, plus their testnets):

```
0x00000000D542a1Afa7A01ECB16254F7A0F8ceB61
```

The address is also exported by the SDK as `YUL_ROUTER_ADDRESS`.

## Design

The router deliberately carries everything it needs — token addresses, pool configs, extension forwardee addresses, and token wrapper addresses — **in calldata**. There are no token or extension jump tables and no stored routes. There is also no public ABI selector: any call that does not come from Ekubo Core is interpreted directly as packed route data. Calls from Core are reserved for the lock callback (selector `0x00000000`); the forward callback (selector `0x00000001`) always reverts.

A single transaction can contain many multi-hop routes. The router executes all of them under **one Core lock**, aggregates the specified and calculated amounts, applies **one slippage check** against the aggregate, and settles token transfers once.

Supported hop types:

| Hop type | Executes |
| --- | --- |
| `core` | A direct `Core.swap` against the pool key |
| `forwarded` | `Core.forward(forwardee, ...)` for forward-only swap extensions such as MEVCapture and [Ve33](../products/ve33.md) |
| `signedExclusiveSwap` | A controller-signed swap on a SignedExclusiveSwap pool (pool key, params, signed meta, minimum balance update, and signature) |
| `wrapper` | Wrapping or unwrapping through an Ekubo token wrapper |

Excluded by design, as a security posture:

* No delegatecall routing (the router checks an immutable self address and rejects delegatecall execution)
* No routing through `Core.forward(router, ...)` — the forward callback reverts
* No protocol or integration fee collection and no fee claiming

The router has been [audited](https://github.com/EkuboProtocol/yul-router/blob/v0.6.0/audits/codex-audit-2026-07-06.md), and CI continuously verifies it against production: live mainnet quotes from the Quoter API are converted to calldata with the SDK and executed against canonical Core on a mainnet fork, covering ETH↔ERC20, ERC20↔ERC20, and exact-output swaps.

## The SDK: `@ekubo/yul-router-sdk`

Routes are encoded with [`@ekubo/yul-router-sdk`](https://www.npmjs.com/package/@ekubo/yul-router-sdk) (published with npm provenance from the repository's release workflow):

```sh
npm install @ekubo/yul-router-sdk
```

### Encoding a swap

`encodeRoutes(...)` is the primary surface. Each entry in `multiHops` is an independent path from `specifiedToken` to `calculatedToken` with its own `specifiedAmount`; the router aggregates them all under one lock and one slippage check. Splitting a trade across multiple multi-hops is how split routes execute atomically.

```typescript
import { encodeRoutes, YUL_ROUTER_ADDRESS } from "@ekubo/yul-router-sdk";

const calldata = encodeRoutes({
  // positive specifiedAmount = exact-in; negative = exact-out
  specifiedToken: WETH,
  calculatedToken: USDC,
  // slippage protection: minimum output (exact-in) or maximum input
  // (exact-out). Required — pass `false` only to explicitly opt into an
  // unbounded threshold.
  calculatedAmountThreshold: minUsdcOut,
  recipient, // optional; defaults to the sender
  multiHops: [
    { specifiedAmount: 10n ** 18n, hops: [{ type: "core", poolKey }] },
    // e.g. a second split through a MEVCapture pool:
    // { specifiedAmount: ..., hops: [{ type: "forwarded", forwardee: MEV_CAPTURE, poolKey: otherPoolKey }] },
  ],
});

// send directly to the router — the calldata IS the route
await wallet.sendTransaction({ to: YUL_ROUTER_ADDRESS, data: calldata });
```

Notes:

* Native ETH is `address(0)` (always `token0`); attach `value` to the transaction when the input is native ETH.
* All multi-hops in one call must agree on direction — mixing exact-in and exact-out throws.
* `encodeRoute(...)` is a convenience wrapper for a single path; `generateCalldata(...)` is an alias of `encodeRoutes(...)`.
* Limits: up to 256 multi-hops per call and 256 hops per multi-hop.

### Signed exclusive swaps

For `signedExclusiveSwap` hops, `encodeSignedSwapMeta({ deadline, fee, nonce, authorizedLocker })` packs the signed metadata word. `deadline` and `fee` are `uint32` numbers; `nonce` must be a `bigint` (a JavaScript `number` is rejected so `uint64` nonces cannot lose precision). `encodePoolBalanceUpdate(delta0, delta1)` packs the signed minimum balance update.

### Other exports

* `YUL_ROUTER_ADDRESS` — the deterministic router address
* `MIN_SQRT_RATIO` / `MAX_SQRT_RATIO` — bounds for `sqrtRatioLimit` on hops (see [Price representation](../reference/price-representation.md))
* `PoolKey`, `Hop`, `MultiHop`, and parameter types for TypeScript consumers
* `calldataSize(data)` — helper for estimating calldata cost

## Typical flow

1. Fetch a quote from the [Quoter API](../reference/quoter-api.md) — it returns block-pinned split routes in exactly the shape the SDK consumes.
2. Convert each split and hop into `multiHops` entries and call `encodeRoutes(...)` with your slippage threshold.
3. Send the calldata to `YUL_ROUTER_ADDRESS` promptly (quotes are pinned to a block).

To deploy the router to a new chain, use the repository's Foundry deploy script — it deploys through the canonical deterministic deployer against the canonical Core address, so the router lands at the same address everywhere.
