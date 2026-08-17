---
description: Pair Ekubo Wallet with a dapp through WalletConnect and review its requests
title: "Use WalletConnect"
---

Ekubo Wallet accepts WalletConnect pairing URIs copied from a dapp's connect-wallet dialog.

1. In the dapp, choose WalletConnect and copy its `wc:` pairing URI.
2. Open **WalletConnect** in Ekubo Wallet and paste the URI.
3. Review the dapp identity and requested networks, then choose the account to expose.
4. Approve or reject later signing and transaction requests in Ekubo Wallet.

The wallet validates the pairing before connecting. An arriving proposal raises the wallet window and a notification naming the dapp, because a pairing is as much a decision as any other request. Multiple dapps can be connected at the same time, and each live session can be disconnected from the **WalletConnect** screen.

Account and chain requests, message signing, typed data, transactions, and supported batched-call requests enter the same native review path as other dapp requests. A connected dapp cannot approve its own request or change the wallet's signing policy.

## Session lifetime

WalletConnect pairings and session keys remain in memory. They do not persist or reconnect after Ekubo Wallet restarts. Explicitly quitting the wallet or installing an update disconnects every live session.

The pairing URI is a secret while it is usable. Copy it only from the dapp you intend to connect, and do not paste a pairing URI into a chat or agent prompt.
