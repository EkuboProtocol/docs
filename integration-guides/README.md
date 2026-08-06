---
description: >-
  The different ways to integrate Ekubo Protocol, and production integrations
  you can use as reference implementations
---

# Integrating Ekubo

There are several ways to integrate Ekubo, depending on what you're building.

### 1. Swap on-chain from a smart contract

Every interaction with Ekubo goes through the Core singleton's [`lock` callback pattern](../concepts/architecture.md): call `lock`, receive a callback, perform swaps and settle net token amounts at the end. See [Swapping](swapping.md) for the flow. On EVM, production swaps go through the gas-optimized [Yul Router](https://github.com/EkuboProtocol/yul-router) with routes encoded by [`@ekubo/yul-router-sdk`](https://www.npmjs.com/package/@ekubo/yul-router-sdk); the Router contracts ([Starknet](https://github.com/EkuboProtocol/starknet-contracts/blob/v5.0.3/src/router.cairo), [EVM](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/Router.sol)) are reference implementations for building your own.

### 2. Quote Ekubo liquidity off-chain (aggregators, solvers)

To route trades through Ekubo pools you need to simulate swaps off-chain. The easiest path is the [Quoter API](../reference/quoter-api.md), which returns block-pinned split routes ready to execute. To compute quotes yourself, use the [SDKs](sdks.md) — the Rust SDK implements every pool type and extension — or see [Price representation](../reference/price-representation.md) and [Pool math](../reference/pool-math.md) to implement the math directly. Remember that pools with [extensions](../concepts/extensions.md) can modify swap behavior; see the [Aggregators guide](aggregators.md) for how to handle them safely.

### 3. Index Ekubo data

The open source [indexer](https://github.com/EkuboProtocol/indexer) ingests Ekubo events on any supported chain into Postgres — it is the same code that powers the [Ekubo API](../reference/ekubo-api/README.md). Run your own instance for low-latency or high-volume needs.

### 4. Connect an AI agent

The public [MCP server](../products/mcp-server.md) at `mcp.ekubo.org` exposes quoting, pool and position data, and unsigned execution plans to any MCP-capable agent.

### 5. Provide exclusive, quoted liquidity

Market makers can run RFQ-style pools where each swap is signed off-chain with its own fee and bounds, while still settling in Ekubo Core — see [Signed exclusive swaps](signed-exclusive-swaps.md).

## SDKs

[`ekubo_sdk`](https://crates.io/crates/ekubo_sdk) (Rust) computes quotes across every pool type; [`@ekubo/sdk`](https://www.npmjs.com/package/@ekubo/sdk) provides pool math in TypeScript; [`@ekubo/yul-router-sdk`](https://www.npmjs.com/package/@ekubo/yul-router-sdk) encodes swap routes for EVM execution. See [SDKs](sdks.md).

## Reference integrations

Production integrations of Ekubo you can use as working examples:

| Integration | Language | What it shows | Ekubo code |
| ----------- | -------- | ------------- | ---------- |
| [KyberSwap dex-lib](https://github.com/EkuboProtocol/kyberswap-dex-lib) | Go | Aggregator pool discovery, state tracking, and swap simulation | [`pkg/liquidity-source/ekubo`](https://github.com/EkuboProtocol/kyberswap-dex-lib/tree/main/pkg/liquidity-source/ekubo) |
| [ParaSwap dex-lib](https://github.com/EkuboProtocol/paraswap-dex-lib) | TypeScript | Aggregator integration with on-chain quoting and event-based state | [`src/dex/ekubo`](https://github.com/EkuboProtocol/paraswap-dex-lib/tree/master/src/dex/ekubo) |
| [Tycho](https://github.com/EkuboProtocol/tycho) | Rust | Substreams-based indexing and off-chain swap simulation of Ekubo V3 | [`protocols/substreams/ethereum-ekubo-v3`](https://github.com/EkuboProtocol/tycho/tree/main/protocols/substreams/ethereum-ekubo-v3), [`crates/tycho-simulation/src/evm/protocol/ekubo_v3`](https://github.com/EkuboProtocol/tycho/tree/main/crates/tycho-simulation/src/evm/protocol/ekubo_v3) |

Questions about an integration? Ask in the [Ekubo Discord](https://discord.ekubo.org).
