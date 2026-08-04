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

See the Routers on [Starknet](https://github.com/EkuboProtocol/starknet-contracts/blob/main/src/router.cairo) and [EVM](https://github.com/EkuboProtocol/evm-contracts/blob/main/src/Router.sol) for examples of how to execute swaps on-chain.
