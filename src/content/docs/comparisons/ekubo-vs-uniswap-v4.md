---
description: >-
  How Ekubo V3 and Uniswap v4 differ on EVM chains: singleton and flash
  accounting, extensions and hooks, fees, ticks and licensing, and when Uniswap
  v4 is the better fit
title: "Ekubo vs Uniswap v4"
---

Ekubo V3 and Uniswap v4 share a design on EVM chains: one singleton contract holds every pool, balances are tracked as deltas in transient storage during a lock and settled once at the end, and a pool can bind a custom logic contract (an Ekubo _extension_, a Uniswap _hook_) as an immutable part of its key. They differ in how that custom logic acts, in fees and tick precision, in licensing, and by a wide margin in how much liquidity and volume each has today. This page sets out each difference with its source, and says where Uniswap v4 is the better choice.

Every Ekubo claim below is linked to the `v3.4.0` release of [`evm-contracts`](https://github.com/EkuboProtocol/evm-contracts/tree/v3.4.0), and every Uniswap claim to [`v4-core` at commit `bea7f6d`][v4-core]. Starknet is out of scope: Ekubo's Starknet contracts differ (see [Protocol architecture](/concepts/architecture/)), and Uniswap v4 is not deployed there.

## At a glance

| Aspect                | Ekubo V3                                                                                                                                             | Uniswap v4                                                                                                                                                                               |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Pool contract         | One [`Core`][e-core] singleton for every pool                                                                                                        | One [`PoolManager`][u-pm] singleton for every pool                                                                                                                                       |
| Settlement            | [`lock()`][e-lock] callback; deltas in transient storage ([`tload`/`tstore`][e-fa]); net settlement when the lock closes                             | [`unlock()`][u-unlock] callback; deltas in transient storage; [`settle`][u-settle] and [`take`][u-take] before the unlock closes                                                         |
| Custom pool logic     | Extension with 8 call points, all notifications that [return nothing][e-callpoints]                                                                  | Hook with 10 callbacks behind [14 permission flags][u-hooks], four of which let a callback return a balance delta                                                                        |
| Custom actions        | [`forward(address)`][e-forward] hands the current lock to another contract, which acts as the locker with its own ABI                                | A hook's own external functions, or custom accounting through returned deltas                                                                                                            |
| Swap fee              | Any `uint64` fraction of 2^64, fixed in the [pool key][e-config]; variable fees come from extensions (MEV capture, Ve33, signed exclusive swaps)     | Any static fee up to [1,000,000 pips (100%)][u-lpfee], or a dynamic-fee pool whose hook calls [`updateDynamicLPFee`][u-dynfee]                                                           |
| Protocol fee          | None in Core, which has no owner. The canonical Positions contract takes 10% of collected swap fees, an [`immutable`][e-positions] set at deployment | A [protocol fee controller][u-protocolfees] set by the owner can set a fee per pool, up to [1000 pips (0.1%) per direction][u-maxprotocolfee]                                            |
| Tick size             | `1.000001^tick`, [0.01 basis point][e-ticks]                                                                                                         | `1.0001^tick`, [1 basis point][u-tickmath]                                                                                                                                               |
| Tick spacing          | Free per pool, 1 to [698,605][e-constants]                                                                                                           | Free per pool, [1 to 32,767][u-tickmath]                                                                                                                                                 |
| Pool types in one key | Concentrated, stableswap (center price and amplification) and full range ([`poolConfig.sol`][e-config])                                              | Concentrated liquidity; other curves need a custom-accounting hook                                                                                                                       |
| License               | [Ekubo DAO Shared Revenue License 1.0](https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/LICENSE)                                           | [BUSL-1.1][u-license] for `v4-core`, converting to MIT on the earlier of 2027-06-15 or a date set at `v4-core-license-date.uniswap.eth`, with additional use grants published by Uniswap |
| Audits                | Listed on [Audits](/reference/audits/)                                                                                                               | Listed in [`v4-core/docs/security/audits`](https://github.com/Uniswap/v4-core/tree/bea7f6d1c11cd5dc4f0d5151ffa37a1c239feee6/docs/security/audits)                                        |

## Extensions and hooks

Both protocols encode which callbacks a logic contract receives in the contract's own address, so the set is fixed when the address is mined: the top byte on Ekubo ([`addressToCallPoints`][e-addr]), the low 14 bits on Uniswap v4. On Ekubo the eight call points are before and after pool initialization, swaps, position updates and fee collection ([`callPoints.sol`][e-callpoints]). On Uniswap v4 the ten callbacks are before and after initialize, add liquidity, remove liquidity, swap and donate, plus four "returns delta" permissions for swaps and liquidity changes ([`Hooks.sol`][u-hooks]).

The difference is how custom logic moves funds. A v4 hook returns `BeforeSwapDelta` or `BalanceDelta` values from its callbacks and receives caller arguments through a `hookData` parameter. An Ekubo extension's callbacks return nothing; to move funds it re-enters Core inside the same lock like any other participant, and a contract that needs its own entry points receives the lock through [`forward`][e-forward]. Ekubo's TWAMM, MEV capture, boosted fees, Ve33 and signed exclusive swap extensions are built this way, and the [Extensions vs. Uniswap v4 hooks](https://blog.ekubo.org/ekubo-extensions-vs-uniswap-v4-hooks/) article walks through each one. See [Extensions](/concepts/extensions/) for the call points and the deployed extensions.

Other EVM protocols with a comparable mechanism include Balancer v3, whose [hooks](https://docs.balancer.fi/concepts/core-concepts/hooks.html) attach to pools at registration and can compute dynamic swap fees, and whose Vault uses [transient accounting](https://docs.balancer.fi/concepts/vault/transient-accounting.html) of the same lock-and-settle kind.

## Gas

On a mainnet fork at block 25999935 (September 17, 2026), one swap through one 0.3% pool cost 110,875 gas on Ekubo through its production Yul router and 144,390 on Uniswap v4 through the Universal Router with Permit2. With minimal routers of the same shape on both sides, the figures were 112,997 and 131,284, and each additional pool in a route added about 24,000 gas on Ekubo and 36,000 on v4. These are recorded measurements for pools without hooks or extensions; any hook or extension changes them. The method, conditions and raw data are on [Gas efficiency](/reference/gas-efficiency/), and the route-length comparison is on [Gas for multi-pool swaps](/comparisons/multi-pool-swap-gas/).

## Liquidity and volume

On DefiLlama on November 23, 2026, Ekubo's total value locked on Ethereum was about $1.4 million and Uniswap v4's about $641 million. Over the preceding seven days DefiLlama recorded about $47.8 million of Ethereum DEX volume for Ekubo and about $3.51 billion for Uniswap v4. The [saved readings](https://github.com/EkuboProtocol/docs/blob/main/benchmarks/comparisons/defillama-2026-11-23.json) name the API endpoints; current values are on DefiLlama's [Ekubo](https://defillama.com/protocol/ekubo) and [Uniswap v4](https://defillama.com/protocol/uniswap-v4) pages.

Depth decides the price of a trade more than per-swap gas does once a trade is large. A lower gas cost does not offset a worse price from a shallower pool.

## When Uniswap v4 is the better choice

- **Large swaps in pairs where Uniswap v4 is much deeper.** On Ethereum that is most major pairs today. Compare routed quotes at your actual size; an aggregator that includes both protocols does this for you.
- **You need a chain Ekubo is not live on.** Ekubo's [supported chains](/reference/contracts/evm-v3/#supported-chains) require EIP-1153 and EIP-7939; check that list against Uniswap's deployments.
- **Your design depends on hook return deltas or `hookData`.** If you already have audited v4 hook code or depend on v4 tooling, porting it to Ekubo's call-point and `forward` model is new work, not a recompile.
- **Your contracts would be derived from or incorporate the core code, and the license terms suit Uniswap better.** Read both licenses with your own counsel; this page does not interpret either.
- **You want the larger hook ecosystem.** More third-party hooks, tooling and integrations target v4 than target Ekubo extensions.

## When Ekubo may fit better

- **Routes that cross several pools.** Ekubo's measured cost per extra pool is lower; see [Gas for multi-pool swaps](/comparisons/multi-pool-swap-gas/).
- **Finer price ranges.** Ekubo ticks are 100 times finer, though a pool's tick spacing sets the real limit; see [Concentrated liquidity ranges](/comparisons/concentrated-liquidity-ranges/).
- **Long-running orders.** The TWAMM extension shares one address on every [supported chain](/reference/contracts/evm-v3/#shared-deterministic-deployments); see [TWAMM and TWAP orders](/comparisons/twamm-and-twap-orders/).
- **No protocol fee in Core.** Core has no owner and no fee switch; fees are applied by the periphery contract you choose.

## Sources

- Ekubo: [`Core.sol`][e-core], [`FlashAccountant.sol`][e-fa], [`callPoints.sol`][e-callpoints], [`poolConfig.sol`][e-config], [`constants.sol`][e-constants], [`ticks.sol`][e-ticks], [`Positions.sol`][e-positions] at `v3.4.0`.
- Uniswap v4: [`PoolManager.sol`][u-pm], [`Hooks.sol`][u-hooks], [`TickMath.sol`][u-tickmath], [`LPFeeLibrary.sol`][u-lpfee], [`ProtocolFees.sol`][u-protocolfees], [`ProtocolFeeLibrary.sol`][u-maxprotocolfee] and the [license][u-license] at `bea7f6d`; Uniswap's [flash accounting](https://developers.uniswap.org/docs/protocols/v4/concepts/flash-accounting) and [hooks](https://developers.uniswap.org/docs/protocols/v4/concepts/hooks) documentation.
- Gas: [Gas efficiency](/reference/gas-efficiency/) and its recorded benchmark data.
- Liquidity and volume: DefiLlama, read November 23, 2026 at 01:09 UTC, [saved readings](https://github.com/EkuboProtocol/docs/blob/main/benchmarks/comparisons/defillama-2026-11-23.json).

[v4-core]: https://github.com/Uniswap/v4-core/tree/bea7f6d1c11cd5dc4f0d5151ffa37a1c239feee6
[u-pm]: https://github.com/Uniswap/v4-core/blob/bea7f6d1c11cd5dc4f0d5151ffa37a1c239feee6/src/PoolManager.sol#L80
[u-unlock]: https://github.com/Uniswap/v4-core/blob/bea7f6d1c11cd5dc4f0d5151ffa37a1c239feee6/src/PoolManager.sol#L104
[u-take]: https://github.com/Uniswap/v4-core/blob/bea7f6d1c11cd5dc4f0d5151ffa37a1c239feee6/src/PoolManager.sol#L291
[u-settle]: https://github.com/Uniswap/v4-core/blob/bea7f6d1c11cd5dc4f0d5151ffa37a1c239feee6/src/PoolManager.sol#L300
[u-dynfee]: https://github.com/Uniswap/v4-core/blob/bea7f6d1c11cd5dc4f0d5151ffa37a1c239feee6/src/PoolManager.sol#L339
[u-hooks]: https://github.com/Uniswap/v4-core/blob/bea7f6d1c11cd5dc4f0d5151ffa37a1c239feee6/src/libraries/Hooks.sol#L29-L47
[u-tickmath]: https://github.com/Uniswap/v4-core/blob/bea7f6d1c11cd5dc4f0d5151ffa37a1c239feee6/src/libraries/TickMath.sol#L8-L28
[u-lpfee]: https://github.com/Uniswap/v4-core/blob/bea7f6d1c11cd5dc4f0d5151ffa37a1c239feee6/src/libraries/LPFeeLibrary.sol#L15-L25
[u-protocolfees]: https://github.com/Uniswap/v4-core/blob/bea7f6d1c11cd5dc4f0d5151ffa37a1c239feee6/src/ProtocolFees.sol#L24-L36
[u-maxprotocolfee]: https://github.com/Uniswap/v4-core/blob/bea7f6d1c11cd5dc4f0d5151ffa37a1c239feee6/src/libraries/ProtocolFeeLibrary.sol#L8
[u-license]: https://github.com/Uniswap/v4-core/blob/bea7f6d1c11cd5dc4f0d5151ffa37a1c239feee6/licenses/BUSL_LICENSE
[e-core]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/Core.sol#L46
[e-fa]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/base/FlashAccountant.sol#L41-L82
[e-lock]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/base/FlashAccountant.sol#L146
[e-forward]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/base/FlashAccountant.sol#L190
[e-addr]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/types/callPoints.sol#L53-L54
[e-callpoints]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/types/callPoints.sol#L5-L12
[e-config]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/types/poolConfig.sol#L6-L11
[e-constants]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/math/constants.sol#L22
[e-ticks]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/math/ticks.sol#L12
[e-positions]: https://github.com/EkuboProtocol/evm-contracts/blob/v3.4.0/src/Positions.sol#L15
