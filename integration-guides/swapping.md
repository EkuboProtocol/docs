---
description: >-
  Integrate Ekubo protocol to provide better prices to swappers or to perform
  arbitrage
---

# 🔄 Swapping

#### Routing

It is your responsibility to find the best list of pools for executing a trade. This is equivalent to finding the best route for arbitrage.

#### Executing swaps on chain

To swap on Ekubo, you must call `ICore#lock`. Ekubo's core contract will call back into your contract with the data you pass, via `IYourContract#locked`. In your lock callback, you execute the swap(s), pay the input, and withdraw the output tokens in no particular order.&#x20;

Note you typically call swap multiple times in a single `locked` callback so you only have to pay the differences.

## EVM: the Yul Router

On EVM chains, swaps today go through the [Yul Router](https://github.com/EkuboProtocol/yul-router) — a gas-focused router written in Yul, used by the Ekubo interface. It is deployed deterministically to the same address on every supported chain:

```
0x00000000D542a1Afa7A01ECB16254F7A0F8ceB61
```

The router takes custom packed calldata (there is no public ABI selector — route data is the calldata), executes any number of multi-hop routes under a single Core lock, aggregates the amounts, applies one slippage check, and settles once. Four hop types are supported:

* `core` — a direct swap against a Core pool
* `forwarded` — a swap through a forward-only extension such as MEVCapture or [Ve33](../user-guides/ve33.md)
* `signedExclusiveSwap` — a controller-signed swap on a SignedExclusiveSwap pool
* `wrapper` — wrapping/unwrapping through an Ekubo token wrapper

By design, the router does not support delegatecall routing, cannot be re-entered via `Core.forward`, and collects no fees. It has been [audited](https://github.com/EkuboProtocol/yul-router/blob/main/audits/codex-audit-2026-07-06.md).

### Using the SDK

Routes are encoded with [`@ekubo/yul-router-sdk`](https://www.npmjs.com/package/@ekubo/yul-router-sdk):

```typescript
import { encodeRoutes, YUL_ROUTER_ADDRESS } from "@ekubo/yul-router-sdk";

const calldata = encodeRoutes({
  // the token whose amount you specify; positive specifiedAmount = exact-in,
  // negative = exact-out
  specifiedToken: WETH,
  calculatedToken: USDC,
  // slippage protection: minimum output (exact-in) or maximum input
  // (exact-out) — required; pass `false` only to opt into no threshold
  calculatedAmountThreshold: minUsdcOut,
  multiHops: [
    {
      specifiedAmount: 10n ** 18n, // 1 WETH exact-in
      hops: [{ type: "core", poolKey }],
    },
    // additional multi-hops split the trade across routes; all execute under
    // one lock with one aggregate slippage check
  ],
});

// send the transaction directly to the router (attach value for native ETH input)
await wallet.sendTransaction({ to: YUL_ROUTER_ADDRESS, data: calldata });
```

Each multi-hop starts from `specifiedToken` and ends at `calculatedToken` through a sequence of hops; splitting a trade across several multi-hops routes it through multiple pools. The SDK also exports `encodeRoute(...)` for a single-path swap, pool key helpers, and the `MIN_SQRT_RATIO`/`MAX_SQRT_RATIO` constants.

## Reference routers

See the Routers on [Starknet](https://github.com/EkuboProtocol/starknet-contracts/blob/main/src/router.cairo) and [EVM](https://github.com/EkuboProtocol/evm-contracts/blob/main/src/Router.sol) for examples of how to execute swaps on-chain from your own contract.
