---
description: >-
  The different ways to integrate Ekubo Protocol, and production integrations
  you can use as reference implementations
---

# Integrating Ekubo

There are three common ways to integrate Ekubo, depending on what you're building.

### 1. Swap on-chain from a smart contract

Every interaction with Ekubo goes through the Core singleton's [`lock` callback pattern](../concepts/till-pattern.md): call `lock`, receive a callback, perform swaps and settle net token amounts at the end. See [Swapping](swapping.md) for the flow. On EVM, production swaps go through the gas-optimized [Yul Router](https://github.com/EkuboProtocol/yul-router) with routes encoded by [`@ekubo/yul-router-sdk`](https://www.npmjs.com/package/@ekubo/yul-router-sdk); the Router contracts ([Starknet](https://github.com/EkuboProtocol/starknet-contracts/blob/main/src/router.cairo), [EVM](https://github.com/EkuboProtocol/evm-contracts/blob/main/src/Router.sol)) are reference implementations for building your own.

### 2. Quote Ekubo liquidity off-chain (aggregators, solvers)

To route trades through Ekubo pools you need to simulate swaps off-chain. The easiest path is the [Quoter API](../reference/quoter-api.md), which returns block-pinned split routes ready to execute. Alternatively, implement the pool math yourself (see [Price representation](../concepts/price-representation.md) and the [Math 1-pager](../concepts/pool-math.md)), use our SDKs, or lean on an existing integration below. Remember that pools with [extensions](../concepts/extensions.md) can modify swap behavior — see the [Aggregators guide](aggregators.md) for how to handle them safely.

### 3. Index Ekubo data

The open source [indexer](https://github.com/EkuboProtocol/indexer) ingests Ekubo events on any supported chain into Postgres — it is the same code that powers the [Ekubo API](../reference/ekubo-api/README.md). Run your own instance for low-latency or high-volume needs.

## SDKs

* **TypeScript**: [`@ekubo/sdk`](https://www.npmjs.com/package/@ekubo/sdk) — quoting, tick/sqrt-ratio math, and routing for both Starknet and EVM
* **Rust**: [rust-sdk](https://github.com/EkuboProtocol/rust-sdk) — the same math for both Starknet and EVM

## Reference integrations

Production integrations of Ekubo you can use as working examples:

| Integration | Language | What it shows | Ekubo code |
| ----------- | -------- | ------------- | ---------- |
| [KyberSwap dex-lib](https://github.com/EkuboProtocol/kyberswap-dex-lib) | Go | Aggregator pool discovery, state tracking, and swap simulation | [`pkg/liquidity-source/ekubo`](https://github.com/EkuboProtocol/kyberswap-dex-lib/tree/main/pkg/liquidity-source/ekubo) |
| [ParaSwap dex-lib](https://github.com/EkuboProtocol/paraswap-dex-lib) | TypeScript | Aggregator integration with on-chain quoting and event-based state | [`src/dex/ekubo`](https://github.com/EkuboProtocol/paraswap-dex-lib/tree/master/src/dex/ekubo) |
| [Tycho](https://github.com/EkuboProtocol/tycho) | Rust | Substreams-based indexing and off-chain swap simulation of Ekubo V3 | [`protocols/substreams/ethereum-ekubo-v3`](https://github.com/EkuboProtocol/tycho/tree/main/protocols/substreams/ethereum-ekubo-v3), [`crates/tycho-simulation/src/evm/protocol/ekubo_v3`](https://github.com/EkuboProtocol/tycho/tree/main/crates/tycho-simulation/src/evm/protocol/ekubo_v3) |

Questions about an integration? Ask in the [Ekubo Discord](https://discord.ekubo.org) — or ask the assistant on this site.
