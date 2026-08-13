---
description: Install Ekubo Wallet, create an account, and set up desktop integrations
title: "Install Ekubo Wallet"
---

Use the native release package provided for your platform. Releases are available for macOS, Windows, and Linux.

After installation, open Ekubo Wallet and accept the legal documents shown by the application. Create a new account or import an existing private key from the **Accounts** screen before connecting an agent or dapp. New keys go directly to the operating system's secure credential storage and are not shown by the wallet.

:::caution
Anyone who obtains an imported or exported private key can control that account. Never paste a private key into a website, chat, issue, log, or agent prompt.
:::

## Connect a supported AI agent

Open **Settings** in Ekubo Wallet. The **Detected agents** section shows supported agents installed on the same computer and whether each is configured. Choose **Install for all agents** to add the local wallet and the public Ekubo service to agents that still need setup.

The wallet writes only connection information to the local wallet entry. It does not put an access token, refresh token, authorization header, or client secret in the agent's configuration file.

The **Agent sessions** section shows the sign-in command for each configured agent. Keep Ekubo Wallet running, start sign-in from the agent, then complete the consent and operating-system authentication steps brought forward by the wallet. The wallet's consent screen shows the available session lifetimes. You can revoke an authorized session later from **Settings**.

See [Use Ekubo Wallet with AI agents](/wallet/agents/) for the request flow and trust boundary.

## Install for Claude Desktop

Claude Desktop uses an Ekubo Wallet MCP Bundle rather than Claude Code's configuration. Download the `ekubo-wallet.mcpb` asset from the wallet release, then in Claude Desktop open **Settings → Extensions → Advanced settings → Install Extension**.

The adapter forwards requests only to the local wallet. It keeps OAuth credentials in process memory, so restarting Claude Desktop can require authorization again. Ekubo Wallet must be running when Claude uses wallet tools.

## Linux owner authentication

Owner-authenticated operations on Linux require the packaged polkit policy to be installed in the system polkit actions directory by an administrator. If the policy is unavailable, Ekubo Wallet reports what must be installed instead of silently bypassing owner authentication.

## Updates

Packaged installations check for stable releases. Ekubo Wallet shows the available version and asks for confirmation before downloading an update. It verifies the downloaded artifact before shutting down to install it. Some Linux package installations use the release page rather than updating in place.
