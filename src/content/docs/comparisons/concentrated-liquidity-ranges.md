---
description: >-
  How narrow a concentrated-liquidity range can be on Ekubo, Uniswap v3 and
  Uniswap v4 on EVM chains, what tick spacing and fees do to that, what a
  position costs in gas, and when Uniswap is the better place for a range
title: "Concentrated liquidity ranges"
---

A concentrated-liquidity position earns fees only while the price is inside its range. How precisely that range can be drawn depends on two things: the protocol's tick size, and the tick spacing of the pool the position is in. This page compares both on Ekubo, Uniswap v3 and Uniswap v4 on EVM chains, adds the gas cost of opening a position and the fees each protocol takes, and says when a Uniswap pool is the better place for a range.

Narrower is not automatically better. A narrower range earns more fees per dollar while the price is inside it, and equally converts faster into the losing asset when the price moves and leaves the range more often. Whether a position is profitable depends on the volume it captures relative to that divergence, not on the protocol. See [Providing liquidity](/products/liquidity/#risk).

## Tick size and tick spacing

| Aspect                 | Ekubo V3                                                              | Uniswap v4                                                   | Uniswap v3                                                                                                                                                               |
| ---------------------- | --------------------------------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Price per tick         | `1.000001^tick`, 0.01 basis point ([`ticks.sol`][e-ticks])            | `1.0001^tick`, 1 basis point ([`TickMath.sol`][u4-tickmath]) | `1.0001^tick`, 1 basis point                                                                                                                                             |
| Tick spacing           | Chosen per pool, 1 to 698,605 ([`constants.sol`][e-constants])        | Chosen per pool, 1 to 32,767 ([`TickMath.sol`][u4-tickmath]) | Fixed by fee tier: 0.05% → 10, 0.3% → 60, 1% → 200 ([`UniswapV3Factory.sol`][u3-factory]); the factory owner can enable more tiers, and 0.01% → 1 is enabled on Ethereum |
| Narrowest range        | One tick spacing: 0.0001% at spacing 1                                | One tick spacing: 0.01% at spacing 1                         | One tick spacing: 0.01% in a 0.01% pool                                                                                                                                  |
| Fee per pool           | Any `uint64` fraction of 2^64 ([`poolConfig.sol`][e-config])          | Any static fee up to 100%, or a dynamic fee set by the hook  | The fee tier                                                                                                                                                             |
| Other liquidity shapes | Stableswap (center price and amplification) and full-range pool types | Through hooks                                                | None                                                                                                                                                                     |

A position's bounds must be multiples of its pool's tick spacing, so the pool sets the real precision. Ekubo's finer tick only helps in a pool whose spacing is small. Each combination of fee, spacing and extension is a separate pool, so a pool with a small spacing may hold little of the pair's liquidity.

## A worked example: ETH/USDC on Ethereum

On November 23, 2026, the Ekubo API listed four ETH/USDC pools on Ethereum ([saved response](https://github.com/EkuboProtocol/docs/blob/main/benchmarks/comparisons/ekubo-eth-usdc-pools-2026-11-23.json)). The concentrated pool with a 0.05% fee and no extension, which held the most liquidity, has a tick spacing of 4,988 ticks. One spacing there is `1.000001^4988`, about a 0.50% price step, so no position in that pool can be narrower than about 0.50%.

The Uniswap v3 USDC/WETH 0.05% pool has a tick spacing of 10, about a 0.10% step ([read in the Uniswap v3 migration guide](/integration-guides/migrating-from-uniswap-v3/#expected-output)). **For this pair on Ethereum, a Uniswap v3 position can be drawn five times narrower than one in the largest Ekubo pool.** An Ekubo pool with a smaller spacing can be created by anyone, but liquidity in a new pool starts at zero.

To find the spacing of any Ekubo pool, read its key from the API (`tick_spacing` in `GET /pair/{chainId}/{tokenA}/{tokenB}/pools`) or decode its `config` as in [Migrating from Uniswap v3](/integration-guides/migrating-from-uniswap-v3/#reading-the-output).

## Gas to open a position

Minting a new full-range position of about 10,000 USDC and 10,000 USDT through each protocol's deployed position manager on the live USDC/USDT pools at Ethereum block 25991868 (September 16, 2026) cost 244,513 gas of execution on Ekubo, 297,390 on Uniswap v4 and 381,653 on Uniswap v3, before the 21,000 base and calldata. Rebalancing a range means removing one position and minting another, so this cost recurs with every re-center; only the mint was measured. Method and data are on [Gas efficiency](/reference/gas-efficiency/#measured-honestly).

## Fees taken from liquidity providers

| Protocol   | Protocol fee on LP income                                                                                                                                                                                                                    |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ekubo      | None in Core. The canonical EVM Positions contract takes 10% of the swap fees a position collects, an [`immutable`][e-positions] fixed for that deployment; no fee on withdrawn principal ([Providing liquidity](/products/liquidity/#fees)) |
| Uniswap v4 | A per-pool protocol fee of up to 0.1% of each swap per direction, set by the [protocol fee controller][u4-protocolfees]                                                                                                                      |
| Uniswap v3 | A per-pool share of each swap fee, `feeProtocol`, that the factory owner can change; it was 1/4 on the USDC/WETH 0.05% pool on 24 October 2026 ([migration guide](/integration-guides/migrating-from-uniswap-v3/#reading-the-output))        |

Read the current value for the pool you use rather than relying on these.

## When a Uniswap pool is the better place for a range

- **The pair trades much more on Uniswap.** Fee income comes from volume. On DefiLlama for the seven days to November 23, 2026, Ethereum DEX volume was about $47.8 million on Ekubo, $3.51 billion on Uniswap v4 and $2.28 billion on Uniswap v3 ([saved readings](https://github.com/EkuboProtocol/docs/blob/main/benchmarks/comparisons/defillama-2026-11-23.json)). A position in a pool that rarely trades earns little, however precise its range.
- **The deep pool for your pair has a smaller spacing on Uniswap**, as in the ETH/USDC example above.
- **You want a dynamic fee.** A Uniswap v4 hook can change a pool's LP fee ([`updateDynamicLPFee`][u4-dynfee]). An Ekubo pool's fee is fixed in its key; extensions such as MEV capture add fees but do not replace the base fee.
- **You rely on tooling or protocols built around Uniswap position NFTs.**

## When Ekubo may fit better

- **A pool with a small spacing already has the liquidity you need**, for example stable pairs, where a 0.01-basis-point tick allows ranges far narrower than 1 basis point.
- **You re-center often.** Each mint costs less gas, as measured above.
- **You want a stableswap or full-range shape** in the same contract and routing as concentrated pools.

## Sources

- Ekubo: [`ticks.sol`][e-ticks], [`constants.sol`][e-constants], [`poolConfig.sol`][e-config] and [`Positions.sol`][e-positions] at `v3.4.0`; [Providing liquidity](/products/liquidity/); [Migrating from Uniswap v3](/integration-guides/migrating-from-uniswap-v3/).
- Ekubo ETH/USDC pools: [Ekubo API](/api/), read November 23, 2026, [saved response](https://github.com/EkuboProtocol/docs/blob/main/benchmarks/comparisons/ekubo-eth-usdc-pools-2026-11-23.json).
- Uniswap v4: [`TickMath.sol`][u4-tickmath], [`PoolManager.sol`][u4-dynfee] and [`ProtocolFees.sol`][u4-protocolfees] at `bea7f6d`.
- Uniswap v3: [`UniswapV3Factory.sol`][u3-factory] at `5ea68a7`.
- Gas: [Gas efficiency](/reference/gas-efficiency/) and its recorded [mint results](https://github.com/EkuboProtocol/docs/tree/694275b6eb320876f89e7447f6cfd9ebc9d68f20/benchmarks/fork).
- Volume: DefiLlama, read November 23, 2026 at 01:09 UTC, [saved readings](https://github.com/EkuboProtocol/docs/blob/main/benchmarks/comparisons/defillama-2026-11-23.json).

[e-ticks]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/math/ticks.sol#L12
[e-constants]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/math/constants.sol#L22
[e-config]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/types/poolConfig.sol#L6-L11
[e-positions]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/Positions.sol#L15
[u4-tickmath]: https://github.com/Uniswap/v4-core/blob/bea7f6d1c11cd5dc4f0d5151ffa37a1c239feee6/src/libraries/TickMath.sol#L8-L28
[u4-dynfee]: https://github.com/Uniswap/v4-core/blob/bea7f6d1c11cd5dc4f0d5151ffa37a1c239feee6/src/PoolManager.sol#L339-L343
[u4-protocolfees]: https://github.com/Uniswap/v4-core/blob/bea7f6d1c11cd5dc4f0d5151ffa37a1c239feee6/src/ProtocolFees.sol#L24-L36
[u3-factory]: https://github.com/Uniswap/v3-core/blob/5ea68a77cb541c6b3812df783be71ba8c081e25f/contracts/UniswapV3Factory.sol#L26-L70
