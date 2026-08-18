---
description: Understand native transaction and signature reviews in Ekubo Wallet
title: "Review requests"
---

Requests that need the owner appear in Ekubo Wallet's **Inbox**. An agent or dapp can create a request, but it cannot operate the review controls or authenticate as the owner.

Every review starts on **Reject**. **Approve** remains unavailable until you reach the end of the complete review. The document keeps the exact payload available alongside interpreted details, including calldata, message bytes, complete typed data, digests, warnings, Unicode controls, and visually confusable characters.

## Before approving

Check the account, network, destination, value, and exact operation. Treat token names, dapp descriptions, simulation output, and agent explanations as context rather than authority. If the request is unexpected or any exact value is wrong, reject it.

Selecting **Approve** starts operating-system owner authentication. After authentication, the wallet reloads the request and active policy and verifies that the reviewed document still matches what will be signed. If anything relevant changed, it does not sign the stale review.

For a transaction, approval also submits the exact signed envelope before the review closes; no agent or dapp has to return and ask the wallet to broadcast it. If every configured endpoint refuses those bytes, the activity remains **Signed** and the wallet reports the failure so **Send now** can retry the same envelope.

Closing a review records no decision. Reopening or refreshing it starts safely on **Reject** again. Cancelling owner authentication leaves the request pending.

Notifications and tray menus do not contain approval actions. Detailed notifications are the default: they name the account and network, while a private preview tells you to open Ekubo Wallet. Neither form shows the request identifier or exact payload. Transactions, message signatures, typed-data signatures, and WalletConnect pairing proposals all raise notifications. Opening a waiting request goes to its exact review; opening a decided or lifecycle update goes to its Activity record. A pairing proposal names the dapp, because at that point there is no account or network to name yet. Return to the native wallet to make a decision.

## Signature reviews

A signature review opens the same way a transaction review does, by stating what approving it lets someone else do, and then shows the exact payload unaltered beneath that reading.

For typed data, an **Effects** section leads. When the payload is a recognized token permit — ERC-2612, a DAI-style permit, a Permit2 allowance, or a Permit2 signature transfer — the review names the amount and token, who may draw it, and the two lifetimes separately: how long the allowance itself lasts and how long the signature stays usable. Showing only the second can make an allowance that effectively never lapses look like one that expires within the hour. A deadline set to a sentinel beyond any readable date is reported as never rather than printed as digits.

Token names and amounts in that reading come from the owner-confirmed token database alone, never from the contract being signed for, so an unlisted token stays unnamed. An effectively unlimited allowance is called unlimited and carries a warning. A Permit2 signature transfer is flagged as one, because the signature itself moves the tokens once and needs no further transaction from the owner. Every recognized permit carries the standing warning that it moves tokens exactly as an on-chain approval does, is redeemed by whoever holds it rather than by this wallet, and will not appear in this wallet's activity when it is used.

A payload the wallet does not recognize as a permit says so plainly, and says that this is not a promise the payload grants nothing — the types and values below are the only authority on what it means. A payload shaped like a permit that names some other account as the owner is still rendered, with a warning saying it is signed for somebody else's benefit; refusing to display it would leave the owner deciding from raw JSON.

Message signatures lead with the fact that nothing moves and that the signature proves control of the signing address to whoever holds it, for as long as they hold it. An ERC-4361 sign-in message is read field by field, including the domain it signs you in to, rather than left as prose. Recognition is structural, so a message that merely mentions signing in is not given a login's framing.

## What policies change

A matching allow rule can let a call proceed without a native review. A local agent can also ask for one otherwise allowed submission to be reviewed, which adds this screen without changing policy. A matching review rule sends it here instead. A matching deny rule rejects it and cannot be overridden from the review screen. If no rule matches, the request follows the ordinary owner-review path. A transaction takes the least permissive result across all of its calls, so one call needing review brings the whole batch here.

Policy rules do not distinguish the requesting agent, automation, or WalletConnect dapp. The same allow rule applies to the same matching transaction from any of those sources; the source shown in the review and activity history is context, not an authorization input.

Typed-data and personal-message signatures always require native review because they can create reusable authority outside a transaction. Read [Signing policies](/wallet/policies/) before allowing recurring agent actions.
