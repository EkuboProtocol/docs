---
description: >-
  Integrate Ekubo protocol to provide better prices to swappers or to perform
  arbitrage
---

# Swapping

### Routing

It is your responsibility to find the best list of pools for executing a trade. This is equivalent to finding the best route for arbitrage. The easiest way to get a route is the [Quoter API](../reference/quoter-api.md), which returns block-pinned split routes ready to execute.

### Executing swaps on-chain

Every interaction with Ekubo starts with `ICore#lock` (see the ["till" pattern](../concepts/architecture.md)). Core calls back into your contract via `IYourContract#locked`; inside the callback you execute the swap(s), pay the input, and withdraw the output tokens, in any order. You typically call `swap` several times in a single `locked` callback so that you only settle the net differences.

### Swapping on EVM chains

Production swaps on EVM chains go through the [Yul Router](yul-router.md) — a gas-optimized router deployed at the same address on every supported chain, with routes encoded by [`@ekubo/yul-router-sdk`](https://www.npmjs.com/package/@ekubo/yul-router-sdk). See the [Yul Router guide](yul-router.md) for the calldata model, hop types, and SDK usage.

### Reference routers

To execute swaps from your own contract, see the reference Router implementations on [Starknet](https://github.com/EkuboProtocol/starknet-contracts/blob/main/src/router.cairo) and [EVM](https://github.com/EkuboProtocol/evm-contracts/blob/main/src/Router.sol).
