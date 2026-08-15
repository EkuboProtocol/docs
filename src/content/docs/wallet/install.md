---
description: Install Ekubo Wallet, create an account, and set up desktop integrations
title: "Install Ekubo Wallet"
---

Download the current stable package from [wallet.ekubo.org](https://wallet.ekubo.org/). The release provides an Apple Silicon DMG for macOS, an x86-64 installer for Windows, and x86-64 AppImage and DEB packages for Linux. The Windows installer is not Authenticode-signed, so Windows can display an Unknown publisher or Microsoft Defender SmartScreen warning.

After installation, open Ekubo Wallet and accept the legal documents shown by the application. Create a new account or import an existing private key from the **Accounts** screen before connecting an agent or dapp. New keys go directly to the operating system's secure credential storage and are not shown by the wallet.

:::caution
Anyone who obtains an imported or exported private key can control that account. Never paste a private key into a website, chat, issue, log, or agent prompt.
:::

## Connect a supported AI agent

Open **Settings** in Ekubo Wallet. The **Detected agents** section shows Codex, Claude Code, Claude Desktop, Gemini CLI, Cursor, OpenCode, and Grok Build when they are present on the same computer. A check or X shows whether each detected agent is configured. Choose **Install** or **Remove** on that row to change only that agent. Installation adds the local wallet and, where the harness configuration supports remote MCP, the public Ekubo service.

Installation status describes the managed configuration entry, not whether an agent process is currently running. A configured agent starts its credential-free stdio bridge when it needs the wallet, and that bridge may connect and disconnect as the agent starts or exits.

The wallet writes an exact `ekubo_wallet` entry containing only the absolute path of its versioned bridge and the fixed `--client <harness>` argument. Where supported, it also writes an `ekubo` entry containing only `https://mcp.ekubo.org/mcp`. Neither entry contains an access token, refresh token, authorization header, client secret, or wallet key. Creating or repairing these credential-free entries does not require owner authentication.

Keep Ekubo Wallet running while an agent uses wallet tools. The installed bridge reconnects when the same wallet version opens or restarts, so the harness can remain open. If the wallet and bridge versions differ during initialization, the bridge exits instead of retrying. Repair that agent's installation in Settings and start a new agent session so the harness launches the matching helper. Closing the wallet window keeps the application available from its tray or menu-bar icon; on macOS, clicking the Dock icon opens the wallet window again.

See [Use Ekubo Wallet with AI agents](/wallet/agents/) for the request flow and trust boundary.

## ChatGPT and Claude Desktop

There is no ChatGPT wallet plugin. Install the Codex connection from the wallet's **Detected agents** settings, then use the ChatGPT desktop app's **Work** or **Code** tab to reach that local MCP server. Ordinary chat modes do not expose the local wallet tools.

There is no Claude Desktop wallet plugin or MCP Bundle. Ekubo Wallet writes Claude Desktop's local stdio entry directly. Claude Desktop does not accept the hosted service in that file, so add a custom connector named **Ekubo** with URL `https://mcp.ekubo.org/mcp` through **Customize → Connectors**. That connector belongs to your Claude account.

Use Claude Desktop in **Code** mode. Claude may classify transaction tools as financial activity and refuse before a request reaches the wallet, especially outside Code mode. If it still refuses, use another supported harness such as Codex, Claude Code, Gemini CLI, Cursor, or OpenCode. The wallet applies the same simulation, policy, and native-review boundary regardless of harness.

## Linux owner authentication

Owner-authenticated operations on Linux require the packaged polkit policy to be installed in the system polkit actions directory by an administrator. If the policy is unavailable, Ekubo Wallet reports what must be installed instead of silently bypassing owner authentication.

## Updates

Packaged installations check for stable releases. Ekubo Wallet shows the available version and asks for confirmation before downloading an update. It verifies the downloaded artifact before shutting down to install it. Some Linux package installations use the release page rather than updating in place.
