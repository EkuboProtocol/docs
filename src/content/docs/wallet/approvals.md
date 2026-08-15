---
description: Understand native transaction and signature reviews in Ekubo Wallet
title: "Review requests"
---

Requests that need the owner appear in Ekubo Wallet's **Inbox**. An agent or dapp can create a request, but it cannot operate the review controls or authenticate as the owner.

Every review starts on **Reject**. **Approve** remains unavailable until you reach the end of the complete review. The document keeps the exact payload available alongside interpreted details, including calldata, message bytes, complete typed data, digests, warnings, Unicode controls, and visually confusable characters.

## Before approving

Check the account, network, destination, value, and exact operation. Treat token names, dapp descriptions, simulation output, and agent explanations as context rather than authority. If the request is unexpected or any exact value is wrong, reject it.

Selecting **Approve** starts operating-system owner authentication. After authentication, the wallet reloads the request and active policy and verifies that the reviewed document still matches what will be signed. If anything relevant changed, it does not sign the stale review.

Closing a review records no decision. Reopening or refreshing it starts safely on **Reject** again. Cancelling owner authentication leaves the request pending.

Notifications and tray menus do not contain approval actions. Detailed notifications are the default: they name the account and network, while a private preview tells you to open Ekubo Wallet. Neither form shows the request identifier or exact payload. Return to the native wallet to make a decision.

## What policies change

A matching allow rule can let a transaction proceed without a native review. A matching deny rule rejects it and cannot be overridden from the review screen. If no rule matches, the request follows the ordinary owner-review path.

Typed-data and personal-message signatures always require native review because they can create reusable authority outside a transaction. Read [Signing policies](/wallet/policies/) before allowing recurring agent actions.
