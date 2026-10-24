---
description: >-
  Map a Uniswap v3 integration onto Ekubo on EVM chains: pool identity, ticks
  and prices, fees, swapping and quoting, extensions, deployments, and licensing
title: "Migrating from Uniswap v3"
---

This guide is for developers who already read from or route through Uniswap v3 and want to add Ekubo, or move to it, on an EVM chain. It maps each Uniswap v3 concept to its Ekubo counterpart, then reads the same ETH/USDC market from both protocols with one script so you can check the mapping against live state.

The two protocols are not interchangeable at the code level. Pools are identified differently, prices and fees are encoded differently, and the SDKs have different surfaces. Plan for a new adapter rather than a configuration change.

## Scope

| Item    | Covered here                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ekubo   | Ekubo V3 on EVM chains. Types and lens contracts are cited from [`evm-contracts` v3.4.0](https://github.com/EkuboProtocol/evm-contracts/tree/v3.4.0); Core, the pool types, and `CoreDataFetcher` are unchanged from the `v3.2.0` deployment listed in [EVM Contracts (V3)](/reference/contracts/evm-v3/). Starknet differs in price and fee encoding (see [Price representation](/reference/price-representation/)) and is not covered. |
| Uniswap | Uniswap v3, cited from [`v3-core` at `5ea68a7`](https://github.com/Uniswap/v3-core/tree/5ea68a77cb541c6b3812df783be71ba8c081e25f) and [`v3-periphery`](https://github.com/Uniswap/v3-periphery). Uniswap v4 is a different design and is not covered.                                                                                                                                                                                    |
| Example | Ethereum mainnet, read-only. No transaction is sent.                                                                                                                                                                                                                                                                                                                                                                                     |

## Concept mapping

| Concept       | Uniswap v3                                                                                                                               | Ekubo V3 on EVM                                                                                                                                                                                                              |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Pool identity | One contract per `(token0, token1, fee)`, found with `UniswapV3Factory.getPool`                                                          | No pool contracts. Every pool lives in the [Core](/concepts/architecture/) singleton and is identified by a `PoolKey` of `token0`, `token1`, and a packed `bytes32 config`. The pool ID is `keccak256(abi.encode(poolKey))`. |
| Native ETH    | Not supported in pools; WETH is used                                                                                                     | Native ETH is `address(0)`, so it is always `token0`. WETH pools are separate pools.                                                                                                                                         |
| Price         | `slot0().sqrtPriceX96`, Q64.96                                                                                                           | `CoreDataFetcher.poolPrice(poolKey)` returns a 64.128 fixed-point sqrt ratio. Core stores a packed 96-bit `SqrtRatio`; see [Price representation](/reference/price-representation/).                                         |
| Tick          | Price `1.0001^tick`, range ±887,272                                                                                                      | Price `1.000001^tick`, range ±88,722,835                                                                                                                                                                                     |
| Tick spacing  | Fixed per fee tier by the factory: 100 → 1, 500 → 10, 3000 → 60, 10000 → 200 on Ethereum                                                 | A free parameter of each concentrated pool, up to 698,605. Stableswap and full-range pools have no tick spacing.                                                                                                             |
| Swap fee      | `uint24` in millionths: `500` is 0.05%                                                                                                   | `uint64` fraction of `2^64`: 0.05% is `9223372036854775` or `9223372036854776`, depending on rounding. Each value is a different pool.                                                                                       |
| Protocol fee  | Per pool, `slot0().feeProtocol`: a share `1/N` of each swap fee, taken at swap time                                                      | Core takes none. The Positions contract takes `SWAP_PROTOCOL_FEE_X64 / 2^64` of fees when a position collects them. Read both live; the example does.                                                                        |
| Swap entry    | `pool.swap(...)` with `uniswapV3SwapCallback`, or a router                                                                               | `Core.lock()`, then swaps inside the lock callback, settling net balances once at the end. Production swaps use the [Yul Router](/integration-guides/yul-router/); see [Swapping](/integration-guides/swapping/).            |
| Quoting       | `QuoterV2`, called with `eth_call`                                                                                                       | The [Quoter API](/api/#quoter) returns block-pinned split routes over HTTP. On-chain, the Yul Router's `quote(bytes)` evaluates a route with `eth_call`. The [Rust SDK](/integration-guides/sdks/) quotes locally.           |
| Hooks         | None                                                                                                                                     | A pool's [extension](/concepts/extensions/) is part of its key and can run at eight call points. Some, such as MEVCapture, must be swapped through `Core.forward` rather than `Core.swap`.                                   |
| LP positions  | `NonfungiblePositionManager` ERC-721                                                                                                     | `Positions` ERC-721, with a manager generation that varies by chain; see [Position and order managers](/reference/contracts/evm-v3/#position-and-order-managers).                                                            |
| Price oracle  | `observe()` on every pool                                                                                                                | Only pools using the Oracle extension record history, and only against native ETH.                                                                                                                                           |
| SDK           | [`@uniswap/v3-sdk`](https://docs.uniswap.org/sdk/v3/overview): `Pool`, `Route`, `Trade`, position helpers                                | [`@ekubo/sdk`](/integration-guides/sdks/) for math and pool-key encoding, `@ekubo/yul-router-sdk` for route encoding, and the Rust `ekubo_sdk` for quoting. There is no `Trade` equivalent.                                  |
| Deployments   | Per-chain factory and periphery addresses; see [Uniswap's deployment list](https://docs.uniswap.org/contracts/v3/reference/deployments/) | Core and lens contracts share one address on every supported chain; see [EVM Contracts (V3)](/reference/contracts/evm-v3/) for chains and the per-chain manager addresses.                                                   |
| License       | `v3-core`: BUSL-1.1 until a change date of 2023-04-01 at the latest, GPL-2.0-or-later after it. `v3-periphery`: GPL-2.0-or-later         | [Ekubo DAO Shared Revenue License 1.0](https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/LICENSE). Read section 7 before shipping a contract that is derived from, or incorporates, the contracts or their ABI.     |

### Converting a tick

The two tick bases differ, so a Uniswap tick does not map to a whole Ekubo tick. For the same token order, `ekuboTick ≈ uniswapTick × ln(1.0001) / ln(1.000001)`, a factor of about 99.99505. When native ETH replaces WETH, the token order can flip, as it does for USDC: USDC is `token0` of the Uniswap pool and `token1` of the Ekubo pool, so the sign flips too. In the example below, Uniswap tick `198574` corresponds to about Ekubo tick `-19856417`.

Converting through the price is safer than converting ticks, because a position bound must also be a multiple of the target pool's tick spacing. Round each bound to that spacing and show the user the resulting price range: it will not equal the original range exactly.

## Run the example

The script reads the Uniswap v3 USDC/WETH 0.05% pool and the Ekubo ETH/USDC pool with a 0.05% fee, a tick spacing of 4988, and no extension, at the same block. It derives the Ekubo pool ID locally with `@ekubo/sdk`.

### Prerequisites

- Node.js 20 or later. The example was run with Node.js 22.23.4 in a fresh `node:22-slim` container.
- An Ethereum mainnet RPC URL in `RPC_URL`. Without one, the script uses the public `https://ethereum-rpc.publicnode.com` endpoint, which can rate-limit.

```sh
npm init -y
npm install viem@2.57.11 @ekubo/sdk@0.0.10
```

`@ekubo/sdk` is an alpha release, so pin the exact version.

Save this as `compare-pools.mjs`:

```js
import {
  createPublicClient,
  http,
  keccak256,
  parseAbi,
  zeroAddress,
} from "viem";
import { mainnet } from "viem/chains";
import {
  decodeEvmPoolConfig,
  deriveEvmPoolId,
  encodeEvmConcentratedPoolConfig,
} from "@ekubo/sdk";

const client = createPublicClient({
  chain: mainnet,
  transport: http(process.env.RPC_URL ?? "https://ethereum-rpc.publicnode.com"),
});

const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

const UNISWAP_V3_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
const EKUBO_CORE_DATA_FETCHER = "0xF68F25CA6C817733b7B15a42191AE72A34d56a2B";
const EKUBO_POSITIONS = "0x02D9876A21AF7545f8632C3af76eC90b5ad4b66D";

const blockNumber = await client.getBlockNumber();
const read = (args) => client.readContract({ ...args, blockNumber });

// USDC per ETH, to 2 decimals, from a sqrt ratio with `shift` fractional bits.
function usdcPerEth(sqrtRatio, shift, ethIsToken0) {
  const ratio = sqrtRatio * sqrtRatio;
  const one = 1n << (2n * shift);
  const scaled = ethIsToken0
    ? (ratio * 10n ** 14n) / one
    : (one * 10n ** 14n) / ratio;
  return `${scaled / 100n}.${(scaled % 100n).toString().padStart(2, "0")}`;
}

const uniPool = await read({
  address: UNISWAP_V3_FACTORY,
  abi: parseAbi([
    "function getPool(address,address,uint24) view returns (address)",
  ]),
  functionName: "getPool",
  args: [USDC, WETH, 500],
});
const uniAbi = parseAbi([
  "function slot0() view returns (uint160 sqrtPriceX96, int24 tick, uint16, uint16, uint16, uint8 feeProtocol, bool)",
  "function liquidity() view returns (uint128)",
  "function fee() view returns (uint24)",
  "function tickSpacing() view returns (int24)",
  "function token0() view returns (address)",
]);
const [slot0, uniLiquidity, uniFee, uniSpacing, uniToken0] = await Promise.all(
  ["slot0", "liquidity", "fee", "tickSpacing", "token0"].map((functionName) =>
    read({ address: uniPool, abi: uniAbi, functionName }),
  ),
);
const [sqrtPriceX96, uniTick, , , , feeProtocol] = slot0;

const poolKey = {
  token0: zeroAddress,
  token1: USDC,
  config: encodeEvmConcentratedPoolConfig({
    fee: 9223372036854776n,
    tickSpacing: 4988,
    extension: zeroAddress,
  }),
};
const poolKeyAbi = "(address token0, address token1, bytes32 config)";
const [sqrtRatioFixed, ekuboTick] = await read({
  address: EKUBO_CORE_DATA_FETCHER,
  abi: parseAbi([
    `function poolPrice(${poolKeyAbi}) view returns (uint256, int32)`,
  ]),
  functionName: "poolPrice",
  args: [poolKey],
});
const [, , ekuboLiquidity] = await read({
  address: EKUBO_CORE_DATA_FETCHER,
  abi: parseAbi([
    `function poolState(${poolKeyAbi}) view returns (uint96, int32, uint128)`,
  ]),
  functionName: "poolState",
  args: [poolKey],
});
const swapProtocolFeeX64 = await read({
  address: EKUBO_POSITIONS,
  abi: parseAbi(["function SWAP_PROTOCOL_FEE_X64() view returns (uint64)"]),
  functionName: "SWAP_PROTOCOL_FEE_X64",
});
const config = decodeEvmPoolConfig(poolKey.config);

console.log(`Ethereum block ${blockNumber}\n`);
console.log("Uniswap v3 USDC/WETH");
console.log(`  pool address    ${uniPool}`);
console.log(`  token0          ${uniToken0}`);
console.log(`  fee             ${uniFee} / 1e6`);
console.log(`  tick spacing    ${uniSpacing}`);
console.log(`  sqrtPriceX96    ${sqrtPriceX96}`);
console.log(`  tick            ${uniTick}`);
console.log(`  liquidity       ${uniLiquidity}`);
console.log(
  `  feeProtocol     ${feeProtocol % 16} (token0), ${feeProtocol >> 4} (token1)`,
);
console.log(`  USDC per ETH    ${usdcPerEth(sqrtPriceX96, 96n, false)}\n`);

console.log("Ekubo ETH/USDC");
console.log(`  pool id         ${deriveEvmPoolId(poolKey, keccak256)}`);
console.log(`  token0          ${poolKey.token0}`);
console.log(`  config          ${poolKey.config}`);
console.log(`  fee             ${config.fee} / 2^64`);
console.log(`  tick spacing    ${config.tickSpacing}`);
console.log(`  extension       ${config.extension}`);
console.log(`  sqrtRatio 64.128 ${sqrtRatioFixed}`);
console.log(`  tick            ${ekuboTick}`);
console.log(`  liquidity       ${ekuboLiquidity}`);
console.log(`  Positions swap protocol fee ${swapProtocolFeeX64} / 2^64`);
console.log(`  USDC per ETH    ${usdcPerEth(sqrtRatioFixed, 128n, true)}`);
```

Run it:

```sh
node compare-pools.mjs
```

### Expected output

Observed on 24 October 2026. The addresses, pool ID, config, fee, tick spacing, and protocol-fee values should match exactly. Prices, ticks, and liquidity change with every block.

```text
Ethereum block 26260884

Uniswap v3 USDC/WETH
  pool address    0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640
  token0          0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
  fee             500 / 1e6
  tick spacing    10
  sqrtPriceX96    1624258718609798137812334441078588
  tick            198574
  liquidity       2152788552292764204
  feeProtocol     4 (token0), 4 (token1)
  USDC per ETH    2379.29

Ekubo ETH/USDC
  pool id         0xde39735c66c6f51669c80e1fde362e42a1b1b927d49dee8d6577765a4e4d38c6
  token0          0x0000000000000000000000000000000000000000
  config          0x00000000000000000000000000000000000000000020c49ba5e353f88000137c
  fee             9223372036854776 / 2^64
  tick spacing    4988
  extension       0x0000000000000000000000000000000000000000
  sqrtRatio 64.128 16596422858715246736812597483405312
  tick            -19856698
  liquidity       8069515514150211
  Positions swap protocol fee 1844674407370955161 / 2^64
  USDC per ETH    2378.75
```

### Reading the output

The two prices agree to within a few hundredths of a percent, which confirms the conversions: Uniswap's price is WETH per USDC in Q64.96 and has to be inverted, while Ekubo's is USDC per ETH in 64.128.

`feeProtocol` of `4` means a quarter of this Uniswap pool's swap fees went to the protocol at that block. `1844674407370955161 / 2^64` is 10%: the share the canonical Ethereum Positions contract takes from fees it collects for Ekubo liquidity providers. Both are configurable, which is why the script reads them rather than hard-coding them.

Active liquidity is in the same units in both protocols, but one pool's liquidity says little about execution. Ekubo has several ETH/USDC pools with different fees, tick spacings, and extensions, and the Quoter API splits across them. Compare routed quotes, not single pools, when deciding where to send a trade.

`config` packs three fields into one word: the extension address in the top 160 bits, the fee in the next 64, and a 32-bit pool-type field. Here that field is `0x8000137c`: the high bit marks a concentrated pool and `0x137c` is the tick spacing 4988. [`poolConfig.sol`](https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/types/poolConfig.sol) defines the layout; `decodeEvmPoolConfig` decodes it.

## Get a quote

Uniswap integrations usually quote through `QuoterV2`. The closest Ekubo equivalent for off-chain routing is the [Quoter API](/api/#quoter), which needs no key:

```sh
curl -s https://prod-api-quoter.ekubo.org/1/1000000000000000000/0x0000000000000000000000000000000000000000/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 \
  | jq '{block_number, total_calculated, estimated_gas_cost, splits: (.splits | length), first_split: (.splits[0] | {amount_specified, amount_calculated, pool_config: .route[0].swap.pool_key.config})}'
```

Observed on 24 October 2026:

```json
{
  "block_number": 26260896,
  "total_calculated": "2365428425",
  "estimated_gas_cost": 412468,
  "splits": 8,
  "first_split": {
    "amount_specified": "750000000000000000",
    "amount_calculated": "1775133060",
    "pool_config": "0x00000000000000000000000000000000000000000020c49ba5e353f88000137c"
  }
}
```

The path is `/{chainId}/{amount}/{specifiedToken}/{otherToken}` with amounts in base units. This request sells 1 ETH. In the observed response, 75% of it routed through the pool the script read; the split count and shares change from block to block. For exact output, make the amount negative and specify the output token: `/1/-2000000000/{USDC}/{ETH}` asks what it costs to receive 2,000 USDC, and `total_calculated` comes back negative because it is an input.

A quote is pinned to `block_number`. To execute it, encode its splits with `@ekubo/yul-router-sdk` as described in [Preparing a swap from the Quoter API](/integration-guides/yul-router/#preparing-a-swap-from-the-quoter-api). The same guide shows how to re-check a route on-chain with `quote(bytes)`.

## Liquidity positions do not migrate atomically

There is no contract that converts a Uniswap v3 position into an Ekubo position. Moving liquidity is two independent operations: remove liquidity and collect fees from the Uniswap `NonfungiblePositionManager`, then deposit into an Ekubo pool through Positions. The price can move between them, the range has to be re-expressed in Ekubo ticks rounded to the new pool's spacing, and the amounts deposited will depend on the price at deposit time.

Choose the target pool deliberately. A fee tier in Uniswap maps to more than one possible Ekubo pool, and a pool with an extension behaves differently from one without. Narrower ranges earn more fees per dollar while the price is inside them and suffer more divergence loss and time out of range when it is not; moving protocols does not change that trade-off.

## When to keep Uniswap v3

Adding Ekubo does not require removing Uniswap. Keep the existing integration, alone or alongside Ekubo, when any of these hold:

- The chain you need is not in Ekubo's [supported chains](/reference/contracts/evm-v3/#supported-chains), or is listed as awaiting EIP-7939.
- Routed Ekubo quotes for your pairs and sizes are consistently worse than what you get today. Compare at the sizes you actually trade.
- Your product depends on Uniswap-specific surfaces: `observe()` on arbitrary pairs, Uniswap position NFTs accepted by other protocols, or tooling built on `@uniswap/v3-sdk` types.
- Your contracts would be derived from or incorporate Ekubo's contracts or ABI, and the [license](https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/LICENSE) terms do not suit you. This page does not interpret the license; read it with your own counsel.

For aggregators and solvers, adding Ekubo as an additional source is the usual pattern. The [Aggregators](/integration-guides/aggregators/) guide and its reference implementations show how others did it.

## Troubleshooting

| Symptom                                                     | Cause and fix                                                                                                                                                                                                                                                                                 |
| ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ekubo price and liquidity are all zero                      | The pool key does not match an initialized pool. Every field counts: WETH instead of `address(0)`, a fee off by one unit, a different tick spacing, or a different extension each name another pool. Find initialized keys with the Quoter API response or the MCP server's `list_pool_keys`. |
| Revert with `TokensMustBeSorted()`                          | `token0` must be the numerically smaller address. Core rejects an unsorted key when a pool is initialized; a read with an unsorted key just returns zero state. With native ETH, `address(0)` is always `token0`.                                                                             |
| The Ekubo price is off by a factor of `10^12`               | The decimal adjustment was skipped or inverted. The sqrt ratio is for `token1` per `token0` in base units, so scale by `10^(decimals0 - decimals1)` for a human price.                                                                                                                        |
| The prices differ by much more than a fraction of a percent | The two reads used different blocks, or one pool has little active liquidity. Pin both reads to one block, as the script does.                                                                                                                                                                |
| HTTP `429` from the RPC                                     | The public endpoint rate-limits. Set `RPC_URL` to your own provider.                                                                                                                                                                                                                          |
| Swaps revert on a chain that has Core deployed              | Some chains still lack the `CLZ` opcode; see [Supported chains](/reference/contracts/evm-v3/#supported-chains).                                                                                                                                                                               |

## Differences this guide does not cover

This guide is the minimum needed to read state and get a quote. A full migration also has to deal with these, each of which is its own piece of work:

- Executing swaps from your own contract inside a Core lock, including settlement and native-ETH payment; see [Swapping](/integration-guides/swapping/).
- Stableswap and full-range pools, which have no tick spacing and use different liquidity math.
- Pools with extensions, including forwarded hops for MEVCapture and Ve33, and quoting their behavior off-chain; see [Aggregators](/integration-guides/aggregators/#note-on-extensions).
- Indexing: Ekubo emits events from Core rather than from per-pool contracts, so pool discovery and state tracking differ. The open-source [indexer](/products/indexer/) is a working reference.
- TWAMM orders, the Oracle extension's interface, boosted fees, and signed exclusive swaps, none of which have a Uniswap v3 equivalent.
- Position management through Positions: minting, ID generation, fee collection, and the per-chain manager generations.
- Starknet, where prices and fees are encoded differently.
