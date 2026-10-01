---
description: >-
  Integrate Ekubo protocol to provide better prices to swappers or to perform
  arbitrage
title: "Swapping"
---

## Routing

It is your responsibility to find the best list of pools for executing a trade. This is equivalent to finding the best route for arbitrage. The easiest way to get a route is the [Quoter API](/api/#quoter), which returns block-pinned split routes ready to execute.

## Executing swaps on-chain

Every interaction that moves tokens starts with `ICore#lock` (see the ["till" pattern](/concepts/architecture/)). Core then calls back into your contract: on Starknet via `ILocker#locked(id, data)`, and on EVM via the zero function selector `0x00000000`, which the reference implementations expose as `locked_6416899205(uint256)` — the numeric suffix is mined so that the selector is zero. Inside the callback you execute the swap(s), pay the input, and withdraw the output tokens, in any order. You typically call `swap` several times in a single `locked` callback so that you only settle the net differences.

## Swapping on EVM chains

Production swaps go through the [Yul Router](/integration-guides/yul-router/) — a gas-optimized router deployed deterministically at the same address on each chain it has been released to, with routes encoded by [`@ekubo/yul-router-sdk`](https://www.npmjs.com/package/@ekubo/yul-router-sdk). Release v0.8.0 is deployed on all 13 mainnets in the [EVM supported chains](/reference/contracts/evm-v3/#supported-chains) table and on 13 testnets; the [release manifest](https://github.com/EkuboProtocol/yul-router/blob/v0.8.0/broadcast/releases/v0.8.0/manifest.json) lists each of the 26 networks. See the [Yul Router guide](/integration-guides/yul-router/) for the calldata model, hop types, and SDK usage.

## Reference routers

To execute swaps from your own contract, see the reference Router implementations on [Starknet](https://github.com/EkuboProtocol/starknet-contracts/blob/v5.0.3/src/router.cairo) and [EVM](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/Router.sol). On EVM, a contract that already holds a Core lock can also run a Yul Router route through `Core.forward` and settle the net result itself; see [forwarded mode](/integration-guides/yul-router/#three-ways-to-execute-a-route).
