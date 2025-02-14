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

### Oracle Extension

The [oracle extension](https://github.com/EkuboProtocol/oracle-extension) has not been audited.

## Ethereum

The Ethereum smart contracts have not been audited. Our contracts on Ethereum are non-upgradeable _and_ expiring. This means that after they are deployed, swaps and deposits can only happen for a fixed amount of time. After that time has passed, the contracts can only be withdrawn from. This forced migration allows us to continue to improve our contracts at launch.

### Starknet L1 Proxy

The Governance Starknet L1 Proxy has been audited and the report can be found on [GitHub](https://github.com/EkuboProtocol/governance/blob/main/l1_proxy/Ekubo_Governance_L1_Proxy.pdf).

