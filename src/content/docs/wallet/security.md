---
description: Understand Ekubo Wallet's custody, local-agent, storage, and network trust boundaries
title: "Security and privacy"
---

Ekubo Wallet keeps private keys and signing inside its core wallet authority. The native application retains owner-only capabilities, while agents receive a narrower interface that cannot approve requests, export keys, install policies, accept legal terms, or change security-sensitive settings.

## Keys and local storage

Wallet state is stored in an encrypted local database. Private keys are placed in the operating system's secure credential service rather than an agent configuration file. Exporting a private key requires owner authentication and an explicit action in the native application.

Agent configuration written by the wallet contains connection settings, not wallet credentials. OAuth grants are attributed to their requesting client and can be revoked from **Settings**.

## Native approval boundary

Reviews begin on **Reject**, expose the exact payload, require the complete document to be viewed, and use operating-system authentication for approval. The wallet rechecks the request and policy after authentication before signing. Read [Review requests](/wallet/approvals/) for the full flow.

## Local agent boundary

The MCP server is reachable only through a fixed loopback endpoint and requires OAuth for MCP requests. It rejects browser-originated requests and unexpected hosts before reading their bodies. Installing the connection entry does not itself grant an agent access.

This boundary protects against accidental and unauthorized local clients. Plaintext loopback traffic cannot protect the wallet from malicious software already running as the same operating-system user. Keep the operating system and local agent software trusted and up to date.

## External services

The wallet contacts the RPC endpoints configured for enabled networks to read state, simulate, and submit transactions. WalletConnect uses its relay while a session is active. Packaged installations contact the release service to check for updates and verify downloaded artifacts before installation.

The application itself does not send private keys to these services. A transaction or signature can still reveal information by its nature, and RPC providers, dapps, WalletConnect infrastructure, and public blockchains have their own privacy properties.

The legal documents displayed inside the installed wallet are authoritative for the version you are using and remain available from **Settings**.
