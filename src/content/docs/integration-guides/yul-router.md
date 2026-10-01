---
description: >-
  The gas-optimized router used for Ekubo swaps on EVM chains, and the
  TypeScript SDK that encodes routes and quotes for it
title: "Yul Router"
---

The [Yul Router](https://github.com/EkuboProtocol/yul-router/tree/v0.8.0) is a gas-focused router written in Yul that executes Ekubo swaps on EVM chains. It is how swaps are executed in production today: the [interface](https://ekubo.org) encodes routes from [Quoter API](/api/#quoter) results and sends them to the router.

This page describes release **v0.8.0** of the router and of `@ekubo/yul-router-sdk`. The repository's `main` branch can contain unreleased changes, so read the source and README at the [`v0.8.0` tag](https://github.com/EkuboProtocol/yul-router/tree/v0.8.0) rather than at `main`.

The router is deployed deterministically on every supported network. Always use `YUL_ROUTER_ADDRESS` exported by the same installed version of `@ekubo/yul-router-sdk` that you use to encode calldata. This keeps the router destination compatible with that version's encoding; do not copy or hard-code an address from documentation.

## Design

The router deliberately carries everything it needs — token addresses, pool configs, extension forwardee addresses, and token wrapper addresses — **in calldata**. There are no token or extension jump tables and no stored routes.

A single route can contain many multi-hop paths. The router executes all of them under **one Core lock**, aggregates the specified and calculated amounts, applies **one slippage check** against the aggregate, and settles token transfers once.

### Three ways to execute a route

The same packed route bytes can be executed in three modes. All three run the identical route, apply the same slippage check, and return the same four-word result `(address specifiedToken, address calculatedToken, int256 specifiedAmount, int256 calculatedAmount)`, so for the same route and starting state their return data is byte-for-byte identical.

| Mode      | How it is called                                               | Settles?                                                    |
| --------- | -------------------------------------------------------------- | ----------------------------------------------------------- |
| Direct    | Send the packed route bytes to the router as calldata          | Yes: pulls the input from the sender and pays the recipient |
| Forwarded | `Core.forward(router, routeData)` from inside an existing lock | No: the debt stays on the caller's lock                     |
| Quote     | `quote(bytes routeData)` on the router                         | No: all state changes are rolled back                       |

**Direct.** There is no public swap selector: any call that does not come from Ekubo Core and does not use the `quote(bytes)` selector is interpreted as packed route data. The router takes a Core lock, executes the route, and settles. ERC20 input is pulled from the caller with `transferFrom`, so approve `YUL_ROUTER_ADDRESS` for the input token first. The output goes to `recipient` if the route encodes one, otherwise to the caller.

**Forwarded.** A contract that already holds a Core lock can pass the same route data through `Core.forward(router, routeData)`. The router executes the route and applies its slippage check but deliberately does **not** settle. It leaves endpoint debt changes of `specifiedAmount` in `specifiedToken` and `-calculatedAmount` in `calculatedToken` on the caller's lock. This lets a locker combine a routed swap with another operation in the same lock, such as adding liquidity, and settle only the net result. Any `recipient` encoded in the route is ignored in this mode, because the original locker owns settlement.

**Quote.** `quote(bytes routeData)` runs the route inside a Core lock, then reverts from the lock callback with a recognized result payload. The public entrypoint catches only that payload and returns the four-word result. Pool and extension state changes are rolled back, and no token balance or approval is needed. It must be called without ETH value. Unrelated route or extension errors are bubbled unchanged, including `SlippageCheckFailed(int256)` if the route's threshold is not met.

Calls that come from Core are reserved for the lock callback (selector `0x00000000`) and the forward callback (selector `0x00000001`). Any other selector from Core reverts.

Amount signs follow one convention in every mode: exact-input amounts are positive and exact-output amounts are negative. `calculatedAmount` is the output for an exact-input route (positive) and the input for an exact-output route (negative).

### Hop types

| Hop type              | Executes                                                                                                                               |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `core`                | A direct `Core.swap` against the pool key; Core dispatches the pool's configured hooks                                                 |
| `forwarded`           | `Core.forward(forwardee, abi.encode(poolKey, params))` for forward-only swap extensions such as MEVCapture and [Ve33](/products/ve33/) |
| `signedExclusiveSwap` | A controller-signed swap on a SignedExclusiveSwap pool (pool key, params, signed meta, minimum balance update, and signature)          |
| `wrapper`             | `Core.forward(wrapper, abi.encode(int256 amount))` to wrap or unwrap through an Ekubo token wrapper                                    |

For `forwarded` and `signedExclusiveSwap` hops, the SDK defaults `forwardee` to the extension encoded in `poolKey.config`; set it explicitly only to route through an adapter.

`core` and `forwarded` hops accept an optional `allowPartial` flag. With it, the router accounts for the amount actually swapped instead of requiring the specified amount to be filled in full. It is only valid on a single-hop path with a nonzero `specifiedAmount`, so a partial fill cannot strand debt in an intermediate token. To move a pool to a target price, use a partial exact-output swap with `specifiedAmount` set to the `int128` minimum and the target as its `sqrtRatioLimit`.

### Excluded by design

- No delegatecall routing (the router checks an immutable self address and rejects delegatecall execution)
- No protocol or integration fee collection and no fee claiming

### Review status

The router's [Codex audit](https://github.com/EkuboProtocol/yul-router/blob/v0.8.0/audits/codex-audit-2026-07-06.md) covered commit `04d29c4` (July 6, 2026). That commit predates the `signedExclusiveSwap` hop (added July 8), forwarded mode (July 25), and `quote(bytes)` and partial routes (July 27); at the audited commit, `Core.forward(router, ...)` was rejected. The Cantina [AI audit scan](/reference/audits/) is dated July 24, 2026, also before forwarded mode, `quote(bytes)`, and partial routes were added. v0.7.1 was additionally reviewed by the CSO (ACCEPT, pinned to `c5a0dc4`, 2026-09-29); the Codex and Cantina reviews covered earlier revisions. v0.8.0 is additionally covered by CSO review (2026-10-01): ACCEPT of the `c5a0dc4..2f849ed` refactor range, pinned to `2f849ed`, which together with the reviewed `2f849ed..262b793` deadline delta and an empty `262b793..v0.8.0` source diff completes CSO coverage of the v0.8.0 router source.

CI continuously checks the router against production: it requests live mainnet quotes from the Quoter API, converts them to calldata with the SDK, and executes that calldata against canonical Core on a mainnet fork at each quote's block. The cases cover ETH to ERC20, ERC20 to ETH, ERC20 to ERC20, and exact-output swaps.

## The SDK: `@ekubo/yul-router-sdk`

Routes are encoded with [`@ekubo/yul-router-sdk`](https://www.npmjs.com/package/@ekubo/yul-router-sdk), which is published with npm provenance from the repository's release workflow:

```sh
npm install @ekubo/yul-router-sdk@0.8.0
```

`viem` is a peer dependency.

### Encoding a swap

`encodeRoutes(...)` is the primary surface. Each entry in `multiHops` is an independent path from `specifiedToken` to `calculatedToken` with its own `specifiedAmount`; the router aggregates them all under one lock and one slippage check. Splitting a trade across multiple multi-hops is how split routes execute atomically.

```typescript
import { encodeRoutes, YUL_ROUTER_ADDRESS } from "@ekubo/yul-router-sdk";

const calldata = encodeRoutes({
  // positive specifiedAmount = exact-in; negative = exact-out
  specifiedToken: WETH,
  calculatedToken: USDC,
  // slippage protection: minimum output (exact-in) or maximum input
  // (exact-out). Required. Pass `false` only to explicitly opt into an
  // unbounded threshold.
  calculatedAmountThreshold: minUsdcOut,
  recipient, // optional; defaults to the sender
  // last unix second the route may execute; see Deadlines below
  deadline: Math.floor(Date.now() / 1000) + 30 * 60,
  multiHops: [
    { specifiedAmount: 10n ** 18n, hops: [{ type: "core", poolKey }] },
    // e.g. a second split through a MEVCapture pool:
    // { specifiedAmount: ..., hops: [{ type: "forwarded", poolKey: otherPoolKey }] },
  ],
});

// send directly to the router: the calldata IS the route
await wallet.sendTransaction({ to: YUL_ROUTER_ADDRESS, data: calldata });
```

Notes:

- Native ETH is `address(0)` (always `token0`). When the input is native ETH, attach the input amount as `value`, or the maximum input for an exact-output route. Unused ETH is refunded to the sender.
- ERC20 input requires an approval of `YUL_ROUTER_ADDRESS` for at least the input amount.
- All multi-hops in one call must agree on direction; mixing exact-in and exact-out throws.
- `encodeRoute(...)` is a convenience wrapper for a single path; `generateCalldata(...)` is an alias of `encodeRoutes(...)`.
- Limits: up to 256 multi-hops per call and 256 hops per multi-hop (`MAX_MULTIHOP_LENGTH`, `MAX_HOP_LENGTH`).

### Deadlines

`encodeRoutes(...)` and `encodeRoute(...)` accept an optional `deadline`: the last Unix timestamp, in seconds, at which the route may execute. It must fit in a `uint32`, and the SDK throws otherwise. The router compares it with the block timestamp before executing any hop: the route may still execute during the deadline second itself, and from the next second it reverts with `DeadlineExpired()` (selector `0x1ab7da6b`). The check applies in all three modes: direct, forwarded, and `quote(bytes)`.

Omitting `deadline` encodes a route that never expires; such a route encodes exactly as it did before deadlines were added. Swaps submitted on behalf of users should always set a deadline. `calculatedAmountThreshold` bounds only the amounts, while a deadline also bounds how long a pool's fee or state can change before the route lands. The [interface](https://ekubo.org) sets a deadline when the user signs, 30 minutes ahead by default, counted from the latest block's timestamp rather than the device clock.

In the encoded route, the deadline is a 4-byte value appended to the header after the optional recipient and signalled by header flag bit 1. Header flag bits above bit 1 are reserved, and the router rejects them with `InvalidRoute()`.

### Quoting a route on-chain

`generateQuoteCalldata(params)` takes the same parameters as `encodeRoutes(...)` and returns calldata for `quote(bytes)`. `encodeQuoteCalldata(routeData)` wraps route bytes you have already encoded. Call the result with `eth_call` and decode it with the exported `YUL_ROUTER_ABI`:

```typescript
import { decodeFunctionResult } from "viem";
import {
  generateQuoteCalldata,
  YUL_ROUTER_ABI,
  YUL_ROUTER_ADDRESS,
} from "@ekubo/yul-router-sdk";

const data = generateQuoteCalldata({
  specifiedToken: WETH,
  calculatedToken: USDC,
  // still required; `false` quotes without a slippage bound
  calculatedAmountThreshold: false,
  multiHops,
});

const { data: result } = await publicClient.call({
  to: YUL_ROUTER_ADDRESS,
  data,
});
const [specifiedToken, calculatedToken, specifiedAmount, calculatedAmount] =
  decodeFunctionResult({
    abi: YUL_ROUTER_ABI,
    functionName: "quote",
    data: result!,
  });
```

`calculatedAmountThreshold` is required here too. The SDK throws if it is omitted, and the router enforces it during a quote exactly as it does during a swap. Pass `false` to read the unbounded result, or pass your real threshold to check that the swap would clear it at the current state.

### Signed exclusive swaps

For `signedExclusiveSwap` hops, `encodeSignedSwapMeta({ deadline, fee, nonce, authorizedLocker })` packs the signed metadata word. `deadline` and `fee` are `uint32` numbers; `nonce` must be a `bigint` (a JavaScript `number` is rejected so `uint64` nonces cannot lose precision). `encodePoolBalanceUpdate(delta0, delta1)` packs the signed minimum balance update.

### Other exports

- `YUL_ROUTER_ADDRESS`: the router compatible with this SDK version's encoding
- `YUL_ROUTER_ABI`: the ABI of the `quote(bytes)` entrypoint
- `MIN_SQRT_RATIO` / `MAX_SQRT_RATIO`: bounds for `sqrtRatioLimit` on hops (see [Price representation](/reference/price-representation/))
- `MIN_CALCULATED_AMOUNT_THRESHOLD` / `MAX_CALCULATED_AMOUNT_THRESHOLD`: the `int128` bounds for `calculatedAmountThreshold`
- `PoolKey`, `Hop`, `MultiHop`, and parameter types for TypeScript consumers
- `calldataSize(data)`: helper for estimating calldata cost

## Preparing a swap from the Quoter API

The [Quoter API](/api/#quoter) returns block-pinned split routes, but **not** in the shape the SDK takes. The Quoter uses snake_case field names and encodes amounts and sqrt ratios as strings; the SDK takes camelCase fields and `bigint` values. Convert each field as follows:

| Quoter response field                         | SDK parameter                              | Conversion                                        |
| --------------------------------------------- | ------------------------------------------ | ------------------------------------------------- |
| `splits[]`                                    | `multiHops[]`                              | One multi-hop per split                           |
| `splits[].amount_specified` (string)          | `multiHops[].specifiedAmount`              | `BigInt(...)`                                     |
| `splits[].route[]`                            | `multiHops[].hops[]`                       | One hop per route node                            |
| `route[].swap.type` (`core` / `forwarded`)    | `hop.type`                                 | Unchanged                                         |
| `route[].swap.pool_key`                       | `hop.poolKey`                              | Same `token0` / `token1` / `config` fields        |
| `route[].swap.sqrt_ratio_limit` (hex string)  | `hop.sqrtRatioLimit`                       | `BigInt(...)`                                     |
| `route[].swap.skip_ahead` (integer)           | `hop.skipAhead`                            | Unchanged                                         |
| `route[].wrapped_token.{underlying, wrapped}` | `{ type: "wrapper", underlying, wrapped }` | Unchanged addresses                               |
| `total_calculated` (string)                   | basis for `calculatedAmountThreshold`      | `BigInt(...)`, then apply your slippage tolerance |

The Quoter does not return the endpoint tokens: `specifiedToken` and `calculatedToken` are the tokens you requested the quote for. For an exact-output request (negative amount), `specifiedToken` is the output token and `calculatedToken` is the input token. `forwarded` hops need no `forwardee`, because the SDK derives it from the extension in `poolKey.config`.

```typescript
import {
  encodeRoutes,
  YUL_ROUTER_ADDRESS,
  type Hop,
} from "@ekubo/yul-router-sdk";

function toHop(node): Hop {
  if (node.wrapped_token) {
    const { underlying, wrapped } = node.wrapped_token;
    return { type: "wrapper", underlying, wrapped };
  }
  const { type, pool_key, sqrt_ratio_limit, skip_ahead } = node.swap;
  return {
    type, // "core" or "forwarded"
    poolKey: pool_key,
    sqrtRatioLimit: BigInt(sqrt_ratio_limit),
    skipAhead: skip_ahead,
  };
}

// quote = await fetch(`https://prod-api-quoter.ekubo.org/${chainId}/${amount}/${specifiedToken}/${calculatedToken}`)
const totalCalculated = BigInt(quote.total_calculated);
const slippageBps = 50n;
const calculatedAmountThreshold =
  totalCalculated < 0n
    ? (totalCalculated * (10_000n + slippageBps)) / 10_000n // exact-out: maximum input
    : (totalCalculated * (10_000n - slippageBps)) / 10_000n; // exact-in: minimum output

const calldata = encodeRoutes({
  specifiedToken,
  calculatedToken,
  calculatedAmountThreshold,
  deadline: Math.floor(Date.now() / 1000) + 30 * 60,
  multiHops: quote.splits.map((split) => ({
    specifiedAmount: BigInt(split.amount_specified),
    hops: split.route.map(toHop),
  })),
});
```

Send the calldata to `YUL_ROUTER_ADDRESS` promptly, since quotes are pinned to a block; the `deadline` bounds how late it can still land. To confirm the route still clears your threshold at the current state, pass the same parameters to `generateQuoteCalldata(...)` first.

## Deploying to a new chain

Use the repository's Foundry deploy script. It deploys through the canonical deterministic deployer against the canonical Core address, so the router lands at the same address everywhere.
