---
description: Understand Ekubo Wallet's custody, local-agent, storage, and network trust boundaries
title: "Security and privacy"
---

Ekubo Wallet keeps private keys and signing inside its core wallet authority. The native application retains owner-only capabilities, while agents receive a narrower interface that cannot approve requests, export keys, install policies, accept legal terms, or change security-sensitive settings.

## Keys and local storage

Wallet state is stored in an encrypted local database. Private keys are placed in the operating system's secure credential service rather than an agent configuration file. Exporting a private key requires owner authentication and an explicit action in the native application.

Agent configuration written by the wallet contains fixed connection settings, not wallet credentials. The local bridge has no OAuth flow, bearer token, or client secret.

## Native approval boundary

Reviews begin on **Reject**, expose the exact payload, require the complete document to be viewed, and use operating-system authentication for approval. The wallet rechecks the request and policy after authentication before signing. Read [Review requests](/wallet/approvals/) for the full flow.

## Local agent boundary

Supported harnesses start the installed MCP bridge over stdio. The bridge connects to same-user local IPC: a private Unix socket on macOS and Linux, or a current-user named pipe on Windows. The wallet verifies the local peer identity and gives the connection only the restricted agent API. Installing the connection entry does not itself grant an agent owner capabilities.

This boundary protects against accidental and unauthorized local clients. Same-user local IPC cannot protect the wallet from malicious software already running as the same operating-system user. Keep the operating system and local agent software trusted and up to date.

## External services

The wallet contacts the RPC endpoints configured for enabled networks to read state, simulate, and submit transactions. It fetches referenced execution plans and read bundles from the public HTTPS URL supplied by their producer. WalletConnect uses its relay while a session is active. Packaged installations contact the release service to check for updates and verify downloaded artifacts before installation.

For harnesses that support a remote MCP entry, agent setup also adds the credential-free public companion `https://mcp.ekubo.org/mcp`. Claude Desktop users add that hosted service as an account-level custom connector instead. The companion is operated by Ekubo, Inc. separately from local wallet custody. It can receive the tool arguments sent by an agent and temporarily store execution plans or other artifact bodies, which can identify a wallet address and intended action. It cannot read wallet keys, approve a request, install policy, or sign. The wallet independently fetches, integrity-checks, simulates, and policy-checks a referenced plan.

The application itself does not send private keys to these services. A transaction or signature can still reveal information by its nature, and RPC providers, dapps, WalletConnect infrastructure, and public blockchains have their own privacy properties.

The legal documents displayed inside the installed wallet are authoritative for the version you are using and remain available from **Settings**.
