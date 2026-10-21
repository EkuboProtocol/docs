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

### Retired: the HuffRouter and `@ekubo/evm-hyper-router-sdk`

The earlier HuffRouter and its npm package `@ekubo/evm-hyper-router-sdk` are retired and must not be integrated. On May 5, 2026 a calldata parsing bug in the deployed routers was exploited to drain ERC-20 approvals from accounts that had approved them; the [post-mortem](https://github.com/EkuboProtocol/huff-router/blob/main/incident-report/README.md) documents the bug. Every published version of the package (`0.0.1` through `0.2.2`, all prereleases, and `0.2.3-alpha.0`) is deprecated on npm, and the routers it targeted are immutable contracts that still hold code, so a remaining approval is still drainable.

| Chain    | Router                                       | Exported by the SDK                                                                      |
| -------- | -------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Ethereum | `0x8f52903d17e2d8d6c77d1a1de0cc975b6b5a0d15` | never (Ekubo V2 generation)                                                              |
| Ethereum | `0x8ccb1ffd5c2aa6bd926473425dea4c8c15de60fd` | `MAINNET_ADDRESS` in `0.1.0-alpha.1`                                                     |
| Ethereum | `0x4f168f17923435c999f5c8565acab52c2218edf2` | `DEPLOYMENTS` chain 1 in `0.2.0-alpha.5` through `0.2.3-alpha.0`                         |
| Arbitrum | `0xc93c4ad185ca48d66fefe80f906a67ef859fc47d` | `DEPLOYMENTS` chain 42161 in `0.2.0-alpha.2` and `0.2.0-alpha.6` through `0.2.3-alpha.0` |

The same package also pointed at that router generation on Sepolia (`0xf9bf8e1f79d8ee9983abf3be674b815d5d499a2e`), Arbitrum Sepolia, Robinhood testnet, and MegaETH (the last three at `0xc93c4ad185ca48d66fefe80f906a67ef859fc47d`).

If an account ever approved one of these routers, set the allowance back to zero on each approved token. To migrate, re-encode routes with `@ekubo/yul-router-sdk` and send them to the `YUL_ROUTER_ADDRESS` it exports: HuffRouter calldata is a different format that the Yul Router rejects with `InvalidRoute`, so changing only the destination address does not work. Three HuffRouter options have no equivalent: `integrationFee` (the Yul Router collects no fees), `delegatecall` execution (rejected by the Yul Router), and the implicit unbounded slippage default (`calculatedAmountThreshold` is required by the Yul SDK). Hop types are renamed from `swap` and `wrappedToken` to `core` (or `forwarded`) and `wrapper`.

## Reference routers

To execute swaps from your own contract, see the reference Router implementations on [Starknet](https://github.com/EkuboProtocol/starknet-contracts/blob/v5.0.3/src/router.cairo) and [EVM](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/Router.sol). On EVM, a contract that already holds a Core lock can also run a Yul Router route through `Core.forward` and settle the net result itself; see [forwarded mode](/integration-guides/yul-router/#three-ways-to-execute-a-route).
