---
description: Audit reports for the Ekubo Protocol contracts
title: "Audits"
---

## Ekubo V3 (EVM)

The current EVM contracts are immutable and have been reviewed by multiple independent auditors and a public competitive audit. All reports live in the [audits directory](https://github.com/EkuboProtocol/evm-contracts/tree/v3.2.0/audits) of the source repository.

| Report                                                                                                                                                                                                                                             | Scope                                                                                                                |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| [Code4rena competitive audit](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/Code4rena%20x%20Ekubo%20audit%20report%202025-11.pdf) (November 2025)                                                                              | The V3 protocol, reviewed publicly by a competitive audit field                                                      |
| [Riley Holterhus audit](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/Ekubo-Riley-Holterhus-Audit.pdf)                                                                                                                         | Core protocol                                                                                                        |
| [Riley Holterhus update](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/Ekubo-Feb-2026-Update-Riley-Holterhus-Audit.pdf) (February 2026)                                                                                        | Changes since the original review                                                                                    |
| [Auctions audit](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/Ekubo-Auctions-Riley-Holterhus-Audit.pdf) — Riley Holterhus                                                                                                     | The Auctions contract                                                                                                |
| [SignedExclusiveSwap review](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/SignedExclusiveSwap-Extension-Audit.md)                                                                                                             | The [signed exclusive swap](/integration-guides/signed-exclusive-swaps/) extension                                   |
| [Ve33 invariants](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/ve33-audit-invariants.md) and [invariant verification](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/ve33-audit-invariant-verification.md) | [Ve33](/products/ve33/) stake backing, voter-fee and emission solvency, vote consistency, and range-aware LP rewards |
| [AI audit scan](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/EkuboProtocol%20Audit%20Scan%20-%20AI%20Scan.pdf)                                                                                                                | Automated review pass                                                                                                |

## Starknet

All Starknet contracts were most recently audited by Plainshift, concluding February 14th, 2025.

[Plainshift audit report — all Starknet contracts](/assets/plainshift%20ekubo.pdf)

The core contracts were audited for 15 engineer-weeks by Nethermind Security.

[Nethermind Security — core contracts (partially redacted)](/assets/NM0123_EKUBO_FINAL_PUBLIC.pdf)

The TWAMM extension, which powers [DCA-enabled pools and DCA orders](/user-guides/dollar-cost-average-orders/), was audited separately.

[Nethermind Security — TWAMM extension](/assets/NM0205_EKUBO_TWAMM.pdf)

The first version of the revenue buybacks contract was also audited.

[Nethermind Security — revenue buybacks](/assets/NM_0282_FINAL_Ekubo_Revenue_Buybacks.pdf)

The limit orders extension, for which order placement is now deprecated, was audited for six engineer-weeks, with the final report delivered January 6th, 2025. The review reported no Critical, High, Medium, or Low severity issues.

[Nethermind Security — limit orders extension](/assets/NM0369_EKUBO_LIMIT_ORDERS.pdf)

## Governance

The Starknet L1 proxy, which lets Starknet governance control contracts on Ethereum, was audited by Cairo Security Clan. The report is [on GitHub](https://github.com/EkuboProtocol/governance/blob/v2.8.0/l1_proxy/Ekubo_Governance_L1_Proxy.pdf).

## Legacy deployments

<details>

<summary>Audits of the deprecated EVM V2 deployment</summary>

These reports cover the [EVM V2 contracts](/reference/contracts/evm-v2/), which are deprecated and superseded by V3. They are retained for reference only.

[Plainshift — V2 deployment](/assets/Ekubo%20EVM%20Deployment%20Plainshift%20Audit.pdf)

[ABDK — V2 core](/assets/ABDK_Ekubo_EkuboProtocol_v_1_0.pdf)

[ABDK — V2 TWAMM](/assets/ABDK_Ekubo_TWAMM_v_1_0.pdf)

[ABDK — V2 TWAMM invariant analysis](/assets/ABDK_Ekubo_InvariantAnalysis_v_1_0.pdf)

</details>
