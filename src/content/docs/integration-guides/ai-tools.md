---
title: AI tools for developers
description: Use Ekubo's reusable extension-authoring skill and source-grounded AI workflow to build EVM extensions with periphery contracts and forwarding.
---

Use an AI coding assistant with the contracts, tests, and a reusable skill in its context. This guide covers **EVM extension development**; do not apply its Solidity callback or forwarding conventions to Starknet contracts.

## Give your assistant the right tools

| Resource                                                                                                               | Use it for                                                                                                   |
| ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| [Extension-authoring skill](https://github.com/EkuboProtocol/evm-contracts/tree/main/skills/ekubo-extension-authoring) | Choosing hooks, separating extension accounting from periphery settlement, and testing forwarded actions.    |
| [EVM contracts and tests](https://github.com/EkuboProtocol/evm-contracts)                                              | Checking exact interfaces, encodings, and behavior at the revision you are building against.                 |
| [Documentation index](/llms.txt) and [full documentation](/llms-full.txt)                                              | Giving an assistant navigable protocol and integration context. Verify implementation claims against source. |
| [MCP server](/products/mcp-server/)                                                                                    | Accessing protocol data and preparing unsigned execution plans from an MCP-capable agent.                    |
| [API reference](/api/) and [SDKs](/integration-guides/sdks/)                                                           | Building off-chain integrations around an extension.                                                         |

### Reuse the extension-authoring skill

The public contracts repository includes the skill we use for extension authoring: [`skills/ekubo-extension-authoring/SKILL.md`](https://github.com/EkuboProtocol/evm-contracts/blob/main/skills/ekubo-extension-authoring/SKILL.md). Its companion `references/extension-patterns.md` and `references/testing-checklist.md` cover architecture and verification. Keep the whole directory together; copying only `SKILL.md` loses those references.

Check out the contract revision you intend to target, then ask your assistant to read those three files. If your assistant supports directory-based skills, copy the entire `ekubo-extension-authoring` directory into its documented project skill location. Otherwise, explicitly include the files in the prompt; automatic skill discovery is not required. The paths inside this skill are relative to the contracts repository, so provide that checkout too.

Start with a prompt like this, replacing the behavior description:

```text
In this evm-contracts checkout, read
skills/ekubo-extension-authoring/SKILL.md and both reference files.

Build an extension that [describe the behavior]. Before editing, identify
the required hooks, accounting invariants, and closest existing tests.
Explain which actions belong in the extension and which in periphery.
Use forward for actions needing settlement or lock-restricted Core calls.
Keep token custody in Core and token settlement in the periphery.
Verify APIs against this checkout, not remembered interfaces.
Implement and test the complete periphery-to-extension path, including
rejected direct swaps if the design is forward-only. Report the revision,
commands run, results, and remaining limitations.
```

Treat this page as the entry point for reusable Ekubo developer skills. When contributing another skill, include its public source, when to use it, all required reference files, and a reproducible verification workflow here. Prefer improving the existing skill over maintaining a second copy of the same architecture rules.

## Build the extension and its periphery together

An extension need not squeeze every action into a pool hook. Use hooks for behavior tied to Core operations, and explicit forwarded actions for extension-specific operations that need the Core lock. Give users a periphery contract with convenient, typed entrypoints.

The recommended split is:

| Layer              | Responsibility                                                                                                                                                                                                                |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Extension          | Validate its actions, maintain deterministic accounting, call Core under the forwarded lock, and return accounting results. Use Core saved balances for token obligations rather than holding or transferring ERC-20s itself. |
| Periphery / locker | Expose user functions, encode forwarded actions, apply user bounds and router conveniences, and settle token payments and withdrawals within the lock.                                                                        |
| Core               | Hold tokens, maintain pool and saved-balance state, and enforce that the lock's token debts are zero at completion.                                                                                                           |

Use `BaseExtension` for hook implementations and add `BaseForwardee` for forwarded entrypoints. Pure accounting actions that neither settle tokens nor require lock-restricted Core calls can remain ordinary external functions, with the appropriate authorization checks. Keep optional funding schedules and economic controllers outside the extension when they are not part of its accounting invariant.

## Follow the lock / forward / settle flow

This is a call-flow sketch, not Solidity calldata:

```text
User -> periphery entrypoint
  -> Core.lock -> periphery lock callback
    -> Core.forward(extension, encoded action)
      -> extension.handleForwardData(original locker, action)
        -> Core operations and saved-balance updates
      <- encoded accounting result
    -> periphery settles net payments / withdrawals
  <- lock completes only when all token debts are zero
```

[`FlashAccountant.forward`](https://github.com/EkuboProtocol/evm-contracts/blob/933c813ca154475a3c7eab8234869f6db151c682/src/base/FlashAccountant.sol) temporarily replaces the active locker address with the forwardee, preserving the lock ID. It restores the prior locker after the callback. Forwarding is a call to the extension, not `delegatecall`, and does not itself transfer tokens.

[`BaseForwardee`](https://github.com/EkuboProtocol/evm-contracts/blob/933c813ca154475a3c7eab8234869f6db151c682/src/base/BaseForwardee.sol) restricts the external forwarded callback to its configured accountant, then passes the original locker and payload to `handleForwardData`. The original locker is the forwarding contract, **not necessarily the end user**. Design action authorization accordingly; the callback restriction alone does not authorize an arbitrary payload.

During the callback, [`Core.updateSavedBalances`](https://github.com/EkuboProtocol/evm-contracts/blob/933c813ca154475a3c7eab8234869f6db151c682/src/Core.sol) keys saved balances by locker address, sorted token pair, and salt. Positive deltas save tokens and negative deltas load them, updating the lock's debt accounting. Under a forward to the extension, those saved balances belong to the extension. Use distinct salts for distinct obligations, such as reserves and claimable rewards.

After forwarding returns, the periphery settles the resulting token obligations in the same lock. See [`BaseRouter.handleLockData`](https://github.com/EkuboProtocol/evm-contracts/blob/933c813ca154475a3c7eab8234869f6db151c682/src/base/BaseRouter.sol) for `payFrom` and `withdraw` usage and native-token handling. Use the repository's [`FlashAccountantLib`](https://github.com/EkuboProtocol/evm-contracts/blob/933c813ca154475a3c7eab8234869f6db151c682/src/libraries/FlashAccountantLib.sol) helpers for the custom lock and forward encoding rather than inventing an ABI from the sketch above.

### Forward-only swaps

For swaps that must run extension logic, [`MEVCapture`](https://github.com/EkuboProtocol/evm-contracts/blob/933c813ca154475a3c7eab8234869f6db151c682/src/extensions/MEVCapture.sol) is a concrete example: its `beforeSwap` reverts with `SwapMustHappenThroughForward`, while its forward handler calls Core swap and accounts for additional fees.

Why does the forwarded swap work? [`ExtensionCallPointsLib`](https://github.com/EkuboProtocol/evm-contracts/blob/933c813ca154475a3c7eab8234869f6db151c682/src/libraries/ExtensionCallPointsLib.sol) skips the swap callback when the current locker is the extension itself. A direct Core swap from another locker reaches the reverting hook; the extension's own forwarded Core swap does not recurse into it.

[`Router._swap`](https://github.com/EkuboProtocol/evm-contracts/blob/933c813ca154475a3c7eab8234869f6db151c682/src/Router.sol) applies default square-root-price limits before forwarding and decodes the returned balance update and pool state. This router forwards to its configured MEV Capture and Ve33 addresses; a new extension is not automatically supported by existing routers. Supply a compatible periphery and document its payload and return format for integrators.

## Verify the complete user path

Ask the assistant to prove the behavior through the periphery, not only by calling the extension in isolation. Follow the skill's testing checklist and the existing [`test/extensions`](https://github.com/EkuboProtocol/evm-contracts/tree/933c813ca154475a3c7eab8234869f6db151c682/test/extensions) patterns:

1. Verify registration, selected call points, and supported pool configurations.
2. Exercise a successful forwarded action through a locker, including returned deltas, saved balances, and final settlement.
3. Test authorization, malformed actions, and pool ownership validation. For forward-only designs, verify direct Core swaps fail.
4. Check accounting boundaries: zero amounts, repeated actions, insufficient reserves, and separation of saved-balance buckets. For range-based rewards, include tick crossings and out-of-range positions.
5. Run the repository's checks and inspect the diff. AI-generated code is a starting point for review, not evidence of correctness.

From the contracts checkout, with the required compiler and dependencies available locally:

```sh
forge fmt
forge build --offline
forge test --offline
forge snapshot --offline
```

The source walkthrough above is pinned to EVM contracts revision `933c813ca154475a3c7eab8234869f6db151c682`. Recheck it against your target revision when interfaces change. For conceptual background, see [Extensions](/concepts/extensions/) and [Protocol architecture](/concepts/architecture/).
