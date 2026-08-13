---
description: Control which agent transactions are allowed, denied, or sent to native review
title: "Signing policies"
---

A signing policy controls recurring transaction requests from agents. It does not grant an agent access to private keys or owner-only settings.

New accounts begin with an empty policy, so transactions ordinarily wait for owner review. Policy rules are evaluated from top to bottom, and the first matching rule decides each call:

- **Allow** lets a matching transaction proceed without asking the owner again.
- **Deny** rejects a matching transaction without an approval override.
- No match sends the transaction to the owner for [native review](/wallet/approvals/).

Every call in a batch must be allowed before the batch can proceed automatically.

## Build a narrow rule

Open **Policies** in Ekubo Wallet to use the guided editor. A rule can constrain the network, destination, native value, and calldata. Conditions in one rule are combined; leaving a field unrestricted broadens what the rule matches.

For contract calls, prefer a full function signature and constraints on its typed arguments. Put narrow exceptions before broader rules because order is part of the policy's authority. The wallet rejects rules that are provably unreachable behind an earlier rule.

:::danger
An unrestricted allow rule permits any transaction the agent can request from that account. Use the narrowest rule that expresses the recurring action you intend.
:::

## Agent proposals

An authorized agent can read the active policy and propose a complete replacement based on its current revision. A proposal does not change permissions. The owner must inspect the permission diff in the native wallet and authenticate before installation.

Do not broaden policy merely to finish the request currently waiting. A one-time action can use the ordinary native review path without changing future permissions.

Display labels, token symbols, RPC simulation output, and other network-provided facts are review context, not policy inputs. Policy matching uses exact transaction fields.
