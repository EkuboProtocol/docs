---
description: Audit reports for the Ekubo Protocol contracts
title: "Audits"
---

## Ekubo V3 (EVM)

The current EVM contracts are immutable and have been reviewed by multiple independent auditors and a public competitive audit. All reports live in the [audits directory](https://github.com/EkuboProtocol/evm-contracts/tree/v3.2.0/audits) of the source repository.

| Report | Scope | Date |
| --- | --- | --- |
| [Code4rena competitive audit](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/Code4rena%20x%20Ekubo%20audit%20report%202025-11.pdf) | The V3 protocol, reviewed publicly by a competitive audit field | November 19 – December 10, 2025 |
| [Riley Holterhus audit](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/Ekubo-Riley-Holterhus-Audit.pdf) | Core protocol | November 18, 2025 |
| [Riley Holterhus update](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/Ekubo-Feb-2026-Update-Riley-Holterhus-Audit.pdf) | Changes since the original review | February 2, 2026 |
| [Auctions audit](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/Ekubo-Auctions-Riley-Holterhus-Audit.pdf) — Riley Holterhus | The Auctions contract | February 18, 2026 |
| [SignedExclusiveSwap review](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/SignedExclusiveSwap-Extension-Audit.md) | The [signed exclusive swap](/integration-guides/signed-exclusive-swaps/) extension | June 30, 2026 |
| [Ve33 invariants](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/ve33-audit-invariants.md) and [invariant verification](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/ve33-audit-invariant-verification.md) | [Ve33](/products/ve33/) stake backing, voter-fee and emission solvency, vote consistency, and range-aware LP rewards | July 2, 2026 |
| [AI audit scan](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/EkuboProtocol%20Audit%20Scan%20-%20AI%20Scan.pdf) — Apex Security Review by Cantina | Automated review pass across the EVM contracts, Starknet contracts, governance, and the Yul router | July 24, 2026 |

## Starknet

The Starknet contracts have been reviewed by Plainshift and, across several separate engagements, by Nethermind Security.

| Report | Scope | Date |
| --- | --- | --- |
| [Plainshift](/assets/plainshift%20ekubo.pdf) | All Starknet contracts | February 14, 2025 |
| [Nethermind Security — core contracts](/assets/NM0123_EKUBO_FINAL_PUBLIC.pdf) (partially redacted) | Core, router, positions and NFT contracts — a fifteen engineer-week review of 4,044 lines | March 22, 2024 |
| [Nethermind Security — TWAMM extension](/assets/NM0205_EKUBO_TWAMM.pdf) | The TWAMM extension, which powers [DCA-enabled pools and DCA orders](/user-guides/dollar-cost-average-orders/) — a six engineer-week review of 1,681 lines | April 4, 2024 |
| [Nethermind Security — revenue buybacks](/assets/NM_0282_FINAL_Ekubo_Revenue_Buybacks.pdf) | The first version of the revenue buybacks contract | September 2, 2024 |
| [Nethermind Security — limit orders extension](/assets/NM0369_EKUBO_LIMIT_ORDERS.pdf) | The limit orders extension, for which order placement is now deprecated — a six engineer-week review of 568 lines | January 6, 2025 |

## Governance

| Report | Scope | Date |
| --- | --- | --- |
| [Cairo Security Clan](/assets/Ekubo_Governance_L1_Proxy.pdf) | The Starknet L1 proxy, which lets Starknet governance control contracts on Ethereum | January 22, 2025 |
| [AI audit scan](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/EkuboProtocol%20Audit%20Scan%20-%20AI%20Scan.pdf) — Apex Security Review by Cantina | Automated review pass; its scope included the governance contracts | July 24, 2026 |

## Legacy deployments

<details>

<summary>Audits of the deprecated EVM V2 deployment</summary>

These reports cover the [EVM V2 contracts](/reference/contracts/evm-v2/), which are deprecated and superseded by V3. They are retained for reference only.

| Report | Scope | Date |
| --- | --- | --- |
| [Plainshift](/assets/Ekubo%20EVM%20Deployment%20Plainshift%20Audit.pdf) | The V2 deployment: core, periphery and the Oracle extension | February 24 – March 17, 2025 |
| [ABDK](/assets/ABDK_Ekubo_EkuboProtocol_v_1_0.pdf) | V2 core | April 1, 2025 |
| [ABDK](/assets/ABDK_Ekubo_TWAMM_v_1_0.pdf) | V2 TWAMM | April 27, 2025 |
| [ABDK](/assets/ABDK_Ekubo_InvariantAnalysis_v_1_0.pdf) | V2 TWAMM invariant analysis | April 12, 2025 |

</details>
