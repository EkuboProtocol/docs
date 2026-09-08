---
description: Architecture and deployed contracts for Ekubo Protocol V3 on EVM chains
title: "EVM Contracts (V3)"
---

Ekubo Protocol V3 is the open-source EVM deployment of Ekubo. The source code lives at [EkuboProtocol/evm-contracts](https://github.com/EkuboProtocol/evm-contracts) and is licensed under the [Ekubo DAO Shared Revenue License](https://ekubo-license-v1.eth.link/). The authoritative deployment table and ABIs are published with each [GitHub release](https://github.com/EkuboProtocol/evm-contracts/releases/latest) — the tables below reflect release `v3.2.0`.

## Architecture

- **Core** is an ownerless, permissionless singleton holding all pools and tokens, using [flash accounting](/concepts/key-concepts/#flash-accounting) and the ["till" pattern](/concepts/architecture/). All interactions start with `lock()`; Core calls back into your contract, which performs swaps and position updates and settles net balances at the end. Native ETH is supported directly as `address(0)` (so ETH is always `token0`).
- **Pool types** — a pool's configuration is packed into a single word (`PoolConfig`: extension, fee, and pool-type parameters):
  - **Concentrated liquidity** — tick-spacing-parameterized, as on Starknet
  - **Stableswap** — liquidity concentrated around a configurable center tick with an amplification factor
  - **Full range** — a zero-amplification stableswap pool; the cheapest option
- **Fees** are a `uint64` binary fraction of `2^64` (e.g. 0.3% = `55340232221128654`). See [Price representation](/reference/price-representation/) for fee and price encodings.
- **Extensions** customize pool behavior at eight lifecycle call points. On EVM, an extension's call points are **encoded in the top byte of its own address** (extensions are deployed by mining an address with the right bits).
- **Periphery** (Positions, Orders, Router, Incentives, ...) is where protocol fees are applied — Core itself takes no fees. The canonical Positions deployment applies a 10% protocol fee to collected swap fees (for the Ekubo DAO) and no withdrawal fee.

For the design rationale, read the [V3 whitepaper](/about-ekubo/v3-whitepaper/).

## Supported chains

Ekubo V3 is deployed on the chains below. This page is the authoritative address
reference; the [GitHub releases](https://github.com/EkuboProtocol/evm-contracts/releases/latest)
carry the source and ABIs.

A chain needs two EVM features for the contracts to work:
[EIP-1153](https://eips.ethereum.org/EIPS/eip-1153) (`TSTORE`/`TLOAD`, used for flash
accounting) and [EIP-7939](https://eips.ethereum.org/EIPS/eip-7939) (`CLZ`, used in the
pool math). Where `CLZ` is missing, the contracts deploy at the usual addresses but
every swap and position update reverts. Such a chain becomes usable the moment it
enables the opcode — no redeployment is needed.

| Chain           | Chain ID | Status            | Position and order managers |
| --------------- | -------- | ----------------- | --------------------------- |
| Ethereum        | 1        | Live              | Original                    |
| Optimism        | 10       | Live              | Recompiled                  |
| BNB Smart Chain | 56       | Live              | Recompiled                  |
| Gnosis          | 100      | Live              | Recompiled                  |
| Unichain        | 130      | Live              | Recompiled                  |
| Polygon         | 137      | Live              | Recompiled                  |
| Monad           | 143      | Live              | Original                    |
| World Chain     | 480      | Awaiting EIP-7939 | Recompiled                  |
| MegaETH         | 4326     | Awaiting EIP-7939 | Original                    |
| Robinhood Chain | 4663     | Live              | Original                    |
| Base            | 8453     | Live              | Original                    |
| Arbitrum        | 42161    | Live              | Original                    |
| Ink             | 57073    | Live              | Recompiled                  |

**Live** means the contracts are deployed, both required opcodes are active, and the
chain is selectable in the [Ekubo interface](https://ekubo.org). Deployments also exist
on several testnets, which this page does not enumerate.

Which manager generation applies per chain is explained under
[Position and order managers](#position-and-order-managers).

## Shared deterministic deployments

These contracts are deployed at the **same address on every chain listed above**. Anyone can deploy them to another compatible network with the [DeployAll script](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/script/DeployAll.s.sol).

### Core and extensions

| Contract                                                                                                                | Address (every chain)                        | Description                                                                                 |
| ----------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------- |
| [Core](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/Core.sol)                                         | `0x00000000000014aA86C5d3c41765bb24e11bd701` | The singleton AMM: all pools, positions, and token custody                                  |
| [MEVCapture](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/extensions/MEVCapture.sol)                  | `0x5555fF9Ff2757500BF4EE020DcfD0210CFfa41Be` | Extension charging extra fees on price-moving swaps, directing that value to LPs            |
| [Oracle](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/extensions/Oracle.sol)                          | `0x517E506700271AEa091b02f42756F5E174Af5230` | Extension recording on-chain price history for token pairs (vs native ETH)                  |
| [TWAMM](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/extensions/TWAMM.sol)                            | `0xd47f1B1eDCfEaBb08F6eBd8FC337c27E636C75BA` | Time-weighted AMM extension powering [DCA orders](/user-guides/dollar-cost-average-orders/) |
| [BoostedFees (concentrated)](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/extensions/BoostedFees.sol) | `0xd4B54d0ca6979Da05F25895E6e269E678ba00f9e` | Extension streaming boosted fee rewards to concentrated-liquidity pools                     |
| [BoostedFees (stableswap)](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/extensions/BoostedFees.sol)   | `0x948b9C2C99718034954110cB61a6e08e107745f9` | Same, for stableswap pools                                                                  |
| [ManualPoolBooster](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/ManualPoolBooster.sol)               | `0xddb1758118F65e13a91497015B8cB26801402761` | Permissionless funding of boosted-fee campaigns for specific pools                          |
| [Incentives](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/Incentives.sol)                             | `0xC52D2656cb8C634263E6A15469588beB9C3Bb738` | Distributes liquidity incentive campaigns                                                   |
| [TokenWrapperFactory](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/TokenWrapperFactory.sol)           | `0xAA166592922C4020cEfA23448054AD070211790a` | Wraps non-standard tokens for safe use with Ekubo                                           |
| [MEVCaptureRouter (legacy)](https://github.com/EkuboProtocol/evm-contracts/blob/v3.1.1/src/MEVCaptureRouter.sol)        | `0xd26f20001a72a18C002b00e6710000d68700ce00` | Legacy `v3.1.1` router for MEVCapture pools (superseded by the configurable Router)         |

### Lens (read-only data fetchers)

| Contract                                                                                                                 | Address (every chain)                        | Description                                                                              |
| ------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------- | ---------------------------------------------------------------------------------------- |
| [CoreDataFetcher](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/lens/CoreDataFetcher.sol)               | `0xF68F25CA6C817733b7B15a42191AE72A34d56a2B` | Pool state, [prices](/integration-guides/reading-pool-price/), positions, saved balances |
| [QuoteDataFetcher](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/lens/QuoteDataFetcher.sol)             | `0x5a3F0F1dA4Ac0c4b937d5685f330704c8e8303f1` | Batched data for computing swap quotes                                                   |
| [TWAMMDataFetcher](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/lens/TWAMMDataFetcher.sol)             | `0xDEFe25E56a7891CC4c0E1401879f3dC81F1Cc4A6` | DCA order and TWAMM state                                                                |
| [IncentivesDataFetcher](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/lens/IncentivesDataFetcher.sol)   | `0x69F9eCfa84CF0C41bE9F68b557b07b6b89d71eD0` | Incentive campaign state                                                                 |
| [PriceFetcher](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/lens/PriceFetcher.sol)                     | `0xFE0Aa09c1CC2bA299b3AaFA52716bE00f40F1D6d` | Oracle price reads for many tokens at once                                               |
| [TokenDataFetcher](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/lens/TokenDataFetcher.sol)             | `0x305Cf9A34dCb265522780D1D64544d3f7C450407` | Token metadata and balances                                                              |
| [BoostedFeesDataFetcher](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/lens/BoostedFeesDataFetcher.sol) | `0x50DabB063ab0B62a33abf49f1357f0981cec241F` | Boosted-fees campaign state                                                              |

### Position and order managers

Unlike the contracts above, the managers do **not** share one address across all
chains. `BasePositions` changed in `v3.2.0` so that generated NFT IDs fit in 192 bits
and map directly to Core position salts; recompiling moved the deterministic CREATE2
addresses. There is no migration — chains that already had the original managers kept
them, and chains onboarded afterwards received the recompiled ones.

Both generations are live, and a position minted through either remains valid. To build
a **new** transaction, use whichever generation the target chain has, per the
[Supported chains](#supported-chains) table:

| Generation                                                                                  | Positions                                    | Orders                                       | Canonical on                                                           |
| ------------------------------------------------------------------------------------------- | -------------------------------------------- | -------------------------------------------- | ---------------------------------------------------------------------- |
| **Original** ([`v3.1.1`](https://github.com/EkuboProtocol/evm-contracts/tree/v3.1.1/src))   | `0x02D9876A21AF7545f8632C3af76eC90b5ad4b66D` | `0x3325428adB409c239E88ca472F50b0efe00E98B4` | Ethereum, Monad, MegaETH, Robinhood Chain, Base, Arbitrum              |
| **Recompiled** ([`v3.2.0`](https://github.com/EkuboProtocol/evm-contracts/tree/v3.2.0/src)) | `0xA2971E0C37cFdb13aE8440A0C94Ef1A1af39e326` | `0x9bB520B6192F71ec3D015C8a74F914f9c94bF794` | Optimism, BNB Smart Chain, Gnosis, Unichain, Polygon, World Chain, Ink |

Most chains in the first row carry **both** generations, because the recompiled managers
were deployed everywhere afterwards; only Robinhood Chain has the original alone. Where
both exist the original is canonical, which is what the Ekubo interface builds against.
[Positions](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/Positions.sol)
is the ERC-721 manager for [liquidity positions](/user-guides/add-liquidity/) and applies
a 10% swap protocol fee for the Ekubo DAO (and no withdrawal fee);
[Orders](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/Orders.sol) is the
ERC-721 manager for [DCA orders](/user-guides/dollar-cost-average-orders/). A few chains
also carry earlier manager deployments that are not canonical and should not be used for
new transactions.

### Deployment-specific contracts

Contracts added or reworked in `v3.2.0` are configuration-specific and have no universal address — their addresses are per deployment:

- [Ve33](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/extensions/Ve33.sol), [VeToken](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/VeToken.sol), [Ve33Positions](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/Ve33Positions.sol), Ve33Periphery, Ve33EmissionRateScheduler, and [Ve33DataFetcher](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/lens/Ve33DataFetcher.sol) — the [Ve33](/products/ve33/) token-governed liquidity system (each instance is deployed around its own stake token, e.g. STONX on Robinhood Chain)
- [SignedExclusiveSwap](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/extensions/SignedExclusiveSwap.sol) — extension for controller-signed EIP-712 swaps ([integration guide](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/signed-exclusive-swap-extension.md))
- [Router](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/Router.sol) — configurable router executing Core swaps and forwarding to MEVCapture / Ve33 pools
- [PoolKeyIndex](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/PoolKeyIndex.sol) — optional registry for discovering initialized pool keys by pool ID, token, or extension
- [Auctions](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/Auctions.sol) — on-chain auctions ([whitepaper](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/auctions-whitepaper.md))
- [MintableERC20](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/MintableERC20.sol) — owner-mintable token used by deployments that need one (e.g. a Ve33 stake token)

Audit reports for the EVM contracts are linked on the [Audits](/reference/audits/) page.
