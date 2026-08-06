---
description: Audit reports for the Ekubo Protocol contracts
---

# Audits

## Ekubo V3 (EVM)

The current EVM contracts are immutable and have been reviewed by multiple independent auditors and a public competitive audit. All reports live in the [audits directory](https://github.com/EkuboProtocol/evm-contracts/tree/v3.2.0/audits) of the source repository.

| Report | Scope |
| --- | --- |
| [Code4rena competitive audit](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/Code4rena%20x%20Ekubo%20audit%20report%202025-11.pdf) (November 2025) | The V3 protocol, reviewed publicly by a competitive audit field |
| [Riley Holterhus audit](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/Ekubo-Riley-Holterhus-Audit.pdf) | Core protocol |
| [Riley Holterhus update](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/Ekubo-Feb-2026-Update-Riley-Holterhus-Audit.pdf) (February 2026) | Changes since the original review |
| [Auctions audit](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/Ekubo-Auctions-Riley-Holterhus-Audit.pdf) — Riley Holterhus | The Auctions contract |
| [SignedExclusiveSwap review](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/SignedExclusiveSwap-Extension-Audit.md) | The [signed exclusive swap](../integration-guides/signed-exclusive-swaps.md) extension |
| [Ve33 invariants](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/ve33-audit-invariants.md) and [invariant verification](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/ve33-audit-invariant-verification.md) | [Ve33](../products/ve33.md) stake backing, voter-fee and emission solvency, vote consistency, and range-aware LP rewards |
| [AI audit scan](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/audits/EkuboProtocol%20Audit%20Scan%20-%20AI%20Scan.pdf) | Automated review pass |

## Starknet

All Starknet contracts were most recently audited by Plainshift, concluding February 14th, 2025.

{% file src="../.gitbook/assets/plainshift ekubo.pdf" %}
Plainshift audit report — all Starknet contracts
{% endfile %}

The core contracts were audited for 15 engineer-weeks by Nethermind Security.

{% file src="../.gitbook/assets/NM0123_EKUBO_FINAL_PUBLIC.pdf" %}
Nethermind Security — core contracts (partially redacted)
{% endfile %}

The TWAMM extension, which powers [DCA-enabled pools and DCA orders](../user-guides/dollar-cost-average-orders.md), was audited separately.

{% file src="../.gitbook/assets/NM0205_EKUBO_TWAMM.pdf" %}
Nethermind Security — TWAMM extension
{% endfile %}

The first version of the revenue buybacks contract was also audited.

{% file src="../.gitbook/assets/NM_0282_FINAL_Ekubo_Revenue_Buybacks.pdf" %}
Nethermind Security — revenue buybacks
{% endfile %}

## Governance

The Starknet L1 proxy, which lets Starknet governance control contracts on Ethereum, was audited by Cairo Security Clan. The report is [on GitHub](https://github.com/EkuboProtocol/governance/blob/v2.8.0/l1_proxy/Ekubo_Governance_L1_Proxy.pdf).

## Legacy deployments

<details>

<summary>Audits of the deprecated EVM V2 deployment</summary>

These reports cover the [EVM V2 contracts](contracts/evm-v2.md), which are deprecated and superseded by V3. They are retained for reference only.

{% file src="../.gitbook/assets/Ekubo EVM Deployment Plainshift Audit.pdf" %}
Plainshift — V2 deployment
{% endfile %}

{% file src="../.gitbook/assets/ABDK_Ekubo_EkuboProtocol_v_1_0.pdf" %}
ABDK — V2 core
{% endfile %}

{% file src="../.gitbook/assets/ABDK_Ekubo_TWAMM_v_1_0.pdf" %}
ABDK — V2 TWAMM
{% endfile %}

{% file src="../.gitbook/assets/ABDK_Ekubo_InvariantAnalysis_v_1_0.pdf" %}
ABDK — V2 TWAMM invariant analysis
{% endfile %}

</details>
