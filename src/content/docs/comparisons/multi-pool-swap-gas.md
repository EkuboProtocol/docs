---
description: >-
  Measured gas for one-, two- and three-pool swap routes on Ethereum through
  Ekubo, Uniswap v4 and Uniswap v3, why the cost per extra pool differs, and
  when gas is not the deciding factor
title: "Gas for multi-pool swaps"
---

A swap that crosses several pools pays for each pool's math, for the token transfers between them, and for the router that strings them together. How those costs grow with route length depends on the AMM's architecture. This page compares Ekubo with Uniswap v4 and Uniswap v3 on Ethereum using recorded measurements, explains where the difference comes from, and says when the gas difference does not matter.

All figures are from the benchmarks on [Gas efficiency](/reference/gas-efficiency/), recorded on a mainnet fork at block 25999935 (September 17, 2026) with fresh ERC20 tokens, 0.3% pools of matched liquidity, no tick crossings, and no hooks or extensions. They are transaction gas: execution plus the 21,000 base plus the calldata. They are not live readings.

## Cost by route length

Minimal single-lock routers of the same shape on every side, which favors Uniswap because its production routers cost more than these minimal ones:

| Pools in the route | Ekubo   | Uniswap v4 | Uniswap v3 |
| ------------------ | ------- | ---------- | ---------- |
| 1                  | 112,997 | 131,284    | 117,006    |
| 2                  | 137,091 | 167,027    | 176,438    |
| 3                  | 161,184 | 202,770    | 235,870    |

Each extra pool added about 24,000 gas on Ekubo, 36,000 on Uniswap v4 and 59,000 on Uniswap v3. At one pool Uniswap v3 is within 4% of Ekubo; at three pools Ekubo's route costs 20.5% less than v4's and 31.7% less than v3's.

Through each protocol's production router (Ekubo's Yul router, the Universal Router with Permit2 for v4, SwapRouter for v3), one pool cost 110,875, 144,390 and 123,587 gas. The v4 Universal Router was measured only at one pool.

## Why the cost per pool differs

**Settlement.** Uniswap v3 has one contract per pool, and each hop transfers tokens out of one pool and into the next, two transfers per pool. Ekubo and Uniswap v4 keep every pool in one singleton contract and track what the caller owes as deltas in transient storage ([EIP-1153](https://eips.ethereum.org/EIPS/eip-1153)), so a route of any length settles with one transfer in and one out. Ekubo's version is the [lock and flash accounting](/concepts/architecture/) in [`FlashAccountant.sol`](https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/base/FlashAccountant.sol#L41-L82); Uniswap's is described in its [flash accounting](https://developers.uniswap.org/docs/protocols/v4/concepts/flash-accounting) documentation. Balancer v3's Vault uses the same kind of [transient accounting](https://docs.balancer.fi/concepts/vault/transient-accounting.html); it was not measured here.

**Pool state.** Ekubo packs a pool's price, tick and liquidity into one storage word, and its swap math uses 64-bit fixed point. In the lab flamegraphs on [Gas efficiency](/reference/gas-efficiency/#why-it-is-cheaper), the pool core cost about 20,000 gas per swap on Ekubo, 29,000 on Uniswap v4 and 37,000 on Uniswap v3. That gap is the main reason Ekubo's marginal pool is cheaper than v4's, since both settle once.

**Calldata.** The Ekubo Yul router encodes a one-pool route in 184 bytes. The Universal Router used 1,092 bytes for a v4 swap with Permit2 funding, and SwapRouter 260 bytes for v3.

**Saved balances.** A contract that trades through Ekubo repeatedly can leave tokens inside Core between transactions ([`updateSavedBalances`](https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/Core.sol#L124)) and skip the transfers entirely. Uniswap v4 offers a comparable facility through [ERC-6909 claim tokens](https://github.com/Uniswap/v4-core/blob/bea7f6d1c11cd5dc4f0d5151ffa37a1c239feee6/src/PoolManager.sol#L80), and Balancer v2's Vault through [internal balances](https://docs-v2.balancer.fi/reference/contracts/apis/vault.html); neither was measured on this page.

## How common multi-pool swaps are

Across a 10% sample of Ethereum mainnet blocks from August 18 to September 17, 2026, 69.1% of swap transactions touched one pool, 16.0% two, 7.4% three and 7.5% four or more, an average of 1.75 pools per swap. The event catalogue and its limits are on [Gas efficiency](/reference/gas-efficiency/#what-this-means-for-the-chain).

## When gas is not the deciding factor

- **Price impact outweighs gas for most sizes that matter.** At the measured blend of 1.75 pools, Ekubo's route used about 27,000 less gas than v4's. Multiply by the gas price to get the saving in ETH and compare it with the difference in output between the protocols' quotes at your size. When one protocol has much deeper liquidity in the pair, its better price is usually worth more than the gas.
- **Liquidity on Ethereum is far deeper on Uniswap.** On DefiLlama on November 23, 2026, Ekubo's Ethereum TVL was about $1.4 million, Uniswap v4's about $641 million and Uniswap v3's about $670 million ([saved readings](https://github.com/EkuboProtocol/docs/blob/main/benchmarks/comparisons/defillama-2026-11-23.json)). For most large swaps, the best route will run mostly or entirely through Uniswap or another deep venue.
- **Mixed routes pay each protocol's cost.** An aggregator route that hops between Ekubo and Uniswap pools settles once per protocol it touches, so the per-pool figures above apply only within one protocol's part of the route.
- **Hooks and extensions change every number.** A v4 hook or an Ekubo extension runs extra code on each swap. Measure the pools you will actually route through.

To compare a real trade, request quotes that include gas from each source at the size you trade, for example with [Compare swap quotes with an AI agent](/integration-guides/compare-swap-quotes-with-an-agent/) or the [Quoter API](/api/#quoter), whose responses include `estimated_gas_cost`.

## Sources

- Route, router and pool-core measurements, conditions and calldata: [Gas efficiency](/reference/gas-efficiency/) and its [recorded results](https://github.com/EkuboProtocol/docs/tree/694275b6eb320876f89e7447f6cfd9ebc9d68f20/benchmarks/prod/snapshots), [harnesses](https://github.com/EkuboProtocol/docs/tree/694275b6eb320876f89e7447f6cfd9ebc9d68f20/benchmarks/prod/test) and [calculation](https://github.com/EkuboProtocol/docs/blob/694275b6eb320876f89e7447f6cfd9ebc9d68f20/benchmarks/page-numbers.mjs).
- Pools per swap: [results](https://github.com/EkuboProtocol/docs/blob/694275b6eb320876f89e7447f6cfd9ebc9d68f20/benchmarks/pools-per-swap/results-30d.json) and [measurement script](https://github.com/EkuboProtocol/docs/blob/694275b6eb320876f89e7447f6cfd9ebc9d68f20/benchmarks/pools-per-swap/measure.mjs).
- Ekubo settlement: [`FlashAccountant.sol`](https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/base/FlashAccountant.sol) and [`Core.sol`](https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/Core.sol) at `v3.4.0`.
- Uniswap v4: [`PoolManager.sol`](https://github.com/Uniswap/v4-core/blob/bea7f6d1c11cd5dc4f0d5151ffa37a1c239feee6/src/PoolManager.sol) and [flash accounting](https://developers.uniswap.org/docs/protocols/v4/concepts/flash-accounting).
- Balancer v3: [transient accounting](https://docs.balancer.fi/concepts/vault/transient-accounting.html).
- Liquidity: DefiLlama, read November 23, 2026 at 01:09 UTC, [saved readings](https://github.com/EkuboProtocol/docs/blob/main/benchmarks/comparisons/defillama-2026-11-23.json).
