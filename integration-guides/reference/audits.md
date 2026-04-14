---
description: The current state of the audits and any public audit reports
---

# Audits

## Starknet

All contracts were most recently audited by Plainshift, concluding February 14th, 2025.

{% file src="../../.gitbook/assets/plainshift ekubo.pdf" %}
Audit report from Plainshift
{% endfile %}

### Core Contracts

Our core contracts were audited for 15 eng-weeks by Nethermind Security.

{% file src="../../.gitbook/assets/NM0123_EKUBO_FINAL_PUBLIC.pdf" %}
Partially redacted version of the report
{% endfile %}

### TWAMM Extension

The TWAMM extension, powering [DCA-enabled pools and DCA orders](../../user-guides/dollar-cost-average-orders.md), has been audited.

{% file src="../../.gitbook/assets/NM0205_EKUBO_TWAMM.pdf" %}

### Revenue buybacks

The [first version of the revenue buybacks contract](https://github.com/EkuboProtocol/revenue-buybacks/releases/tag/v1.0.0) has been audited.

{% file src="../../.gitbook/assets/NM_0282_FINAL_Ekubo_Revenue_Buybacks.pdf" %}

## Ethereum

The Ethereum Ekubo Protocol smart contracts have been audited by both ABDK and Plainshift. The Ethereum smart contracts are immutable.

### Ekubo Protocol Audits

Audits for our V3 smart contracts can be found in the [audits directory](https://github.com/EkuboProtocol/evm-contracts/tree/main/audits) of our source code. Below are audits of older versions of the EVM smart contracts.

{% file src="../../.gitbook/assets/Ekubo EVM Deployment Plainshift Audit.pdf" %}
Plainshift V2 audit report
{% endfile %}

{% file src="../../.gitbook/assets/ABDK_Ekubo_EkuboProtocol_v_1_0.pdf" %}
ABDK V2 Core Audit Report
{% endfile %}

{% file src="../../.gitbook/assets/ABDK_Ekubo_InvariantAnalysis_v_1_0.pdf" %}
ABDK V2 TWAMM Invariant Analysis
{% endfile %}

{% file src="../../.gitbook/assets/ABDK_Ekubo_TWAMM_v_1_0.pdf" %}
ABDK V2 TWAMM Audit
{% endfile %}

### Starknet L1 Proxy

The Governance Starknet L1 Proxy has been audited by Cairo Security Clan and the report can be found on [GitHub](https://github.com/EkuboProtocol/governance/blob/main/l1_proxy/Ekubo_Governance_L1_Proxy.pdf).
