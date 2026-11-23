---
description: >-
  How Ekubo's TWAMM orders compare with CoW Protocol TWAP orders and Fraxswap
  for selling or buying a token gradually on EVM chains, including the limits
  of each design
title: "TWAMM and TWAP orders"
---

Selling or buying a large amount gradually, rather than in one swap, reduces the price impact any single moment has to absorb. On EVM chains there are two broad designs. A **TWAMM** (time-weighted average market maker), first described by [Paradigm](https://www.paradigm.xyz/2021/07/twamm), executes the order continuously inside an AMM as a stream of infinitesimal virtual trades. A **TWAP order** splits the order into a fixed number of ordinary orders placed at intervals. This page compares Ekubo's TWAMM with CoW Protocol's TWAP orders and with Fraxswap, another TWAMM, and states the limits of each.

## At a glance

| Aspect           | Ekubo TWAMM                                                                                                                                                               | CoW Protocol TWAP                                                                              | Fraxswap                                                                                  |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Design           | TWAMM extension on an Ekubo pool; virtual orders executed against that pool                                                                                               | A large order split into a chosen number of limit orders at fixed intervals, filled by solvers | TWAMM embedded in a constant-product AMM based on Uniswap V2                              |
| Execution        | Continuous sale rate, settled at most once per block, whenever anyone touches the pool                                                                                    | Discrete parts, each filled by a solver from any liquidity it finds                            | Continuous; pending orders run once per block, before any other interaction with the pair |
| Price protection | None: an order has no minimum price ([`orderConfig.sol`][e-orderconfig]). It can be stopped at any time                                                                   | Optional minimum price per part; a part does not execute below it                              | None described in its documentation                                                       |
| Liquidity used   | Only the TWAMM pool the order names, after netting against opposite orders                                                                                                | Whatever the solver routes through                                                             | The Fraxswap pair                                                                         |
| Pool shape       | Full range only ([`TWAMM.sol`][e-fullrange])                                                                                                                              | Not applicable                                                                                 | Full range (constant product)                                                             |
| Timing           | Start and end are multiples of a step that is 256 seconds at minimum on EVM and grows with distance into the future ([`time.sol`][e-time]); up to just under 2^32 seconds | Number of parts and total duration chosen by the user                                          | Order expiries aligned to the hour                                                        |
| Account          | Any account; each order is an ERC-721 minted by [`Orders`][e-orders]                                                                                                      | A Safe wallet with CoW's upgraded fallback handler                                             | Not stated in its documentation                                                           |
| Minimum size     | None in the `Orders` contract                                                                                                                                             | $1,000 on Ethereum mainnet; $5 on Gnosis Chain, Arbitrum One and Base                          | Not stated in its documentation                                                           |

CoW Protocol facts are from its [TWAP orders](https://docs.cow.fi/cow-protocol/concepts/order-types/twap-orders) documentation and Fraxswap facts from its [overview](https://docs.frax.finance/fraxswap/overview) and [technical specifications](https://docs.frax.finance/fraxswap/technical-specifications), all read on November 23, 2026.

## How Ekubo's TWAMM works

An Ekubo order sells one token of a pair at a constant rate between a start and an end time. Orders on both sides of the same pool are netted against each other, and only the imbalance is swapped against the pool's liquidity, so volume that nets pays no swap fee. Pending virtual orders run before any swap, position update or fee collection on the pool ([`TWAMM.sol`][e-before]), and anyone can trigger them ([`lockAndExecuteVirtualOrders`][e-execute]). In practice that means at most once per block. Placing, reducing and collecting an order go through the [`Orders`][e-orders] contract, which [`forward`s](/comparisons/ekubo-vs-uniswap-v4/#extensions-and-hooks) the order into the extension; reducing an order is [`decreaseSaleRate`][e-decrease].

The TWAMM extension shares one address on every [supported EVM chain](/reference/contracts/evm-v3/#shared-deterministic-deployments) and also exists on Starknet. For the app flow see [Dollar-cost average orders](/user-guides/dollar-cost-average-orders/).

## Limits of Ekubo's TWAMM

- **No price floor.** If the market moves against the order, it keeps selling. Watch it, or stop it with `decreaseSaleRate`.
- **One pool.** The order executes only against the TWAMM pool for its pair and fee ([`orderKey.sol`][e-orderkey]). A pair without such a pool cannot take orders, and the order's price depends on that pool's liquidity during the order. On Ethereum on November 23, 2026, the ETH/USDC TWAMM pool with a 0.3% fee held about 17.1 ETH and 29,400 USDC ([saved API response](https://github.com/EkuboProtocol/docs/blob/main/benchmarks/comparisons/ekubo-eth-usdc-pools-2026-11-23.json)). Arbitrage against other venues pulls the pool's price back toward the market, but a thin pool still limits how fast an order can sell without moving the price.
- **Full-range liquidity.** TWAMM pools cannot hold concentrated positions, so their liquidity is spread over every price.
- **Exact output is not supported**, because the amount received is not known until the order runs.

## When another design fits better

- **You need a minimum price.** CoW Protocol's TWAP orders let each part refuse to fill below a set price.
- **You want each part filled from the deepest liquidity available.** A TWAP part is an ordinary order that a solver can route anywhere; an Ekubo order is limited to its pool.
- **The pair has no Ekubo TWAMM pool, or a thin one.** Use a venue where the pair is liquid, or add liquidity to the Ekubo TWAMM pool first.
- **You are already in the Frax ecosystem.** Fraxswap is built for protocol-owned liquidity and monetary-policy orders.

## When Ekubo's TWAMM may fit better

- **You want continuous execution** at a constant rate rather than a few discrete fills.
- **You are not using a Safe**, or the order is below CoW's minimum size on the chain you use.
- **There is flow on the other side.** Opposite orders net against each other without paying the pool fee.

## Sources

- Ekubo: [`TWAMM.sol`][e-twamm], [`time.sol`][e-time], [`orderConfig.sol`][e-orderconfig], [`orderKey.sol`][e-orderkey] and [`Orders.sol`][e-orders] at `v3.4.0`; [Dollar-cost average orders](/user-guides/dollar-cost-average-orders/); [Audits](/reference/audits/) (Nethermind's TWAMM review covers the Starknet extension).
- Ekubo ETH/USDC pools on Ethereum: `GET /pair/1/{ETH}/{USDC}/pools` on the [Ekubo API](/api/), read November 23, 2026, [saved response](https://github.com/EkuboProtocol/docs/blob/main/benchmarks/comparisons/ekubo-eth-usdc-pools-2026-11-23.json).
- TWAMM design: [Paradigm, "TWAMM"](https://www.paradigm.xyz/2021/07/twamm).
- CoW Protocol: [TWAP orders](https://docs.cow.fi/cow-protocol/concepts/order-types/twap-orders).
- Fraxswap: [overview](https://docs.frax.finance/fraxswap/overview) and [technical specifications](https://docs.frax.finance/fraxswap/technical-specifications).

[e-twamm]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/extensions/TWAMM.sol
[e-fullrange]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/extensions/TWAMM.sol#L622
[e-before]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/extensions/TWAMM.sol#L639-L659
[e-execute]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/extensions/TWAMM.sol#L597
[e-time]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/math/time.sol#L12-L38
[e-orderconfig]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/types/orderConfig.sol#L4-L5
[e-orderkey]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/types/orderKey.sol#L51-L53
[e-orders]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/Orders.sol
[e-decrease]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/Orders.sol#L77
