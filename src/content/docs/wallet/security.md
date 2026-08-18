---
description: Understand Ekubo Wallet's custody, local-agent, storage, and network trust boundaries
title: "Security and privacy"
---

Within the wallet process and its supported MCP interface, Ekubo Wallet keeps private keys and signing inside its core wallet authority. The native application retains owner-only capabilities, while agents receive a narrower interface that cannot approve requests, export keys, install policies, accept legal terms, or change security-sensitive settings. The current Windows and Linux credential backends have a separate same-user extraction weakness described below.

## Keys and local storage

Wallet state is stored in an encrypted local database. Private keys and the database key are placed in the operating system's credential service rather than an agent configuration file. Exporting a private key through Ekubo Wallet requires owner authentication and an explicit action in the native application.

Agent configuration written by the wallet contains fixed connection settings, not wallet credentials. The local bridge has no OAuth flow, bearer token, or client secret.

## Windows and Linux credential-store limitation

:::caution[Current Windows and Linux builds do not provide application-scoped key custody]
Malware running as the same operating-system user can extract raw account private keys and the SQLCipher database key without using Ekubo Wallet or satisfying owner authentication. Once extracted, a private key can sign elsewhere and bypass wallet policy, native review, and wallet audit records.
:::

The Windows build uses generic Windows Credential Manager entries. Microsoft documents that [generic credentials can be read and written by user processes](https://learn.microsoft.com/en-us/windows/win32/secauthn/kinds-of-credentials). The service and account names identify an entry; they do not restrict it to Ekubo Wallet.

The Linux build uses the Secret Service default collection. The [Secret Service specification](https://specifications.freedesktop.org/secret-service/latest/ch10.html) does not require application access controls, and GNOME states that [any application with the same user's privileges can read secrets in an unlocked keyring](https://wiki.gnome.org/Projects%282f%29GnomeKeyring%282f%29SecurityFAQ.html). Other Secret Service implementations may differ, but Ekubo Wallet does not establish or verify an application-specific restriction on Linux.

A prompt-injected agent is relevant when its harness can run shell commands, programs, or arbitrary code as the desktop user. Such an agent can call the operating-system credential API directly. This is not a key export through MCP: the MCP server never returns raw key material, but its restrictions cannot govern an attacker that bypasses the wallet process. Closing the wallet does not delete the persistent credential entries.

SQLCipher still protects a copied database when the database key is unavailable, and the operating-system credential service protects against other users and offline disk access. Those controls do not protect a live Windows or Linux session from same-user malware. Until the custody mechanism changes, use valuable accounts on those platforms only if you trust every process and local agent allowed to run as the wallet user.

The current macOS build uses Keychain item access controls. Apple documents that [the creating application is automatically trusted and access is tracked using its code-signing requirement](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/AboutCS/AboutCS.html). This is a stronger application boundary, but it does not protect a compromised wallet process, signing identity, authenticated owner session, or operating system.

## Native approval boundary

Reviews begin on **Reject**, expose the exact payload, require the complete document to be viewed, and use operating-system authentication for approval. The wallet rechecks the request and policy after authentication before signing. Read [Review requests](/wallet/approvals/) for the full flow.

## Owner-only settings

Changes that can widen signing authority or replace trusted inputs require operating-system owner authentication. This includes widening or ambiguously changing a signing policy, adding or editing a network, enabling a disabled network, and adding or replacing trusted token metadata.

Three native owner actions are fail-safe reductions and do not open a fresh operating-system challenge: installing a policy that the wallet proves only tightens the active policy, disabling the exact network currently displayed, and removing the exact trusted-token row currently displayed. The wallet verifies current state again at its encrypted persistence boundary and commits the change atomically. Agents cannot invoke any of these owner-only settings operations.

## Transaction policy scope

Signing policy belongs to a wallet account rather than to a particular requester. Rules match exact calls and prepared transaction fields; they do not match the MCP client, harness, automation, dapp, WalletConnect session, or displayed plan source. The same allow rule therefore applies to an equivalent transaction requested by a local agent, an installed automation, or a connected WalletConnect dapp. Source labels remain useful review and audit context, but they grant and restrict nothing.

Personal-message and typed-data signatures always require native review. For transactions, a local agent may ask for one otherwise allowed submission to receive review; that can only add a prompt and cannot override a deny or approve anything.

## Local agent boundary

Supported harnesses start the installed MCP bridge over stdio. The bridge connects to same-user local IPC: a private Unix socket on macOS and Linux, or a current-user named pipe on Windows. The wallet verifies the local peer identity and gives the connection only the restricted agent API. Installing the connection entry does not itself grant an agent owner capabilities.

Restricted does not mean read-only. The local MCP server can read and persist the typed wallet state needed for proposals and transaction lifecycles, and it can ask the wallet's core authority to use an operating-system-held key when the active policy allows an exact transaction automatically. It cannot obtain raw key material, export a key, decide a native review, authenticate as the owner, install policy, accept legal terms, or change owner-only settings.

It can also install an [automation](/wallet/automations/), which schedules bytecode the wallet polls and whose returned calls enter that same guarded path. An automation adds a source of proposed transactions and no signing or authorization path, so it cannot exceed the policy already installed; it is additionally bound to the policy revision it was installed against, and a later policy change stops it until the owner looks at it again.

This boundary protects against accidental and unauthorized local clients. It does not protect against malicious software already running as the same operating-system user. On Windows and Linux, that software can also use the [credential-store limitation](#windows-and-linux-credential-store-limitation) to retrieve keys directly, including after prompt injection into an agent harness with local code-execution capability. Keep the operating system and local agent software trusted and up to date.

## Notifications

Notifications use detailed previews by default, and are raised for transactions, message and typed-data signature requests, and WalletConnect pairing proposals. Their titles disclose lifecycle state, and their bodies name the local account and configured network, except for a pairing proposal, which names the dapp because no account or network has been chosen yet. They do not contain request identifiers, exact calldata, or approval and rejection actions. When private previews are in effect, the identifying details are replaced by an instruction to open Ekubo Wallet. A waiting request opens its exact review; a decided request or transaction lifecycle update opens Activity. The operating system controls whether either form appears on a lock screen or remains in notification history.

## External services

The wallet contacts the RPC endpoints configured for enabled networks to read state, simulate, and submit transactions. It fetches referenced execution plans and read bundles from the public HTTPS URL supplied by their producer. WalletConnect uses its relay while a session is active. Packaged installations contact the release service to check for updates and verify downloaded artifacts before installation.

For harnesses that support a remote MCP entry, agent setup also adds the credential-free public companion `https://mcp.ekubo.org/mcp`. Claude Desktop users add that hosted service as an account-level custom connector instead. The companion is operated by Ekubo, Inc. separately from local wallet custody. It can receive the tool arguments sent by an agent and temporarily store execution plans or other artifact bodies, which can identify a wallet address and intended action. It cannot read wallet keys, approve a request, install policy, or sign. The wallet independently fetches, integrity-checks, simulates, and policy-checks a referenced plan.

The application itself does not send private keys to these services. A transaction or signature can still reveal information by its nature, and RPC providers, dapps, WalletConnect infrastructure, and public blockchains have their own privacy properties.

The legal documents displayed inside the installed wallet are authoritative for the version you are using and remain available from **Settings**.
