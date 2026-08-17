---
description: Run installed bytecode on a schedule so the wallet reacts to on-chain conditions without a live agent
title: "Automations"
---

An automation is EVM runtime bytecode plus a schedule, installed against one wallet and one network. On each tick Ekubo Wallet runs that bytecode against live chain state and reads back a list of calls. A tick that returns no calls ends there. A tick that returns calls turns them into one atomic batch and hands it to the same path every other transaction takes: exact simulation, evaluation against the active [signing policy](/wallet/policies/), and only then a signature.

The feature exists for latency. An agent that would otherwise have to be awake and holding a conversation to notice a chain condition instead compiles the condition once and lets the wallet watch for it.

Automations have their own tab in the native application, directly after **Policies**, because an automation is only ever as permitted as the policy it runs under.

## An automation adds no authority

An automation is a source of proposed transactions, not a permission. It supplies calls the same way an agent supplies an execution plan, and the policy decides whether any of them send. There is no automation-specific signing path and no policy exemption.

That is why installing one is not a widening of authority, and why it does not open an approval dialog. Bytecode can only emit calls; every call is evaluated against the installed policy at send time, and a batch that does not resolve to allow for every call never reaches the signer. An automation that an owner installs and then forgets is bounded by the policy they installed, in the same way an agent they leave running is.

Automations run only while the application is running and the wallet is unlocked. There is no headless or background service mode, and nothing runs after you quit.

## What one tick does

A tick polls the bytecode through an `eth_simulateV1` request against the network's configured endpoint, with the bytecode installed as the code at the wallet's own address and the call originating from that same address. Inside the poll, `msg.sender` is the wallet, which is what makes a `msg.sender`-gated `claim` or `withdraw` behave during the poll the way it will behave in the batch the wallet actually sends.

The bytecode exposes one entry point:

```solidity
interface IEkuboAutomation {
    struct Call {
        address to;
        uint256 value;
        bytes data;
    }

    /// Runs as the wallet, at the wallet's address, inside a simulation whose
    /// writes are discarded. Deliberately not `view`: probe freely.
    function automate(bytes calldata config) external returns (Call[] memory);
}
```

The poll's writes are discarded with the rest of the simulation. Nothing the bytecode does during a tick reaches the chain; only the calls it returns can, and only after the policy allows them.

An empty array means there is nothing to do, which is the normal, healthy outcome of most ticks. A non-empty array becomes a single batch that succeeds or reverts as a unit. A revert, or a return value that is not an `(address,uint256,bytes)[]`, is a failed tick.

Because the poll uses `eth_simulateV1`, the network's endpoint has to support that method. An endpoint that does not will fail every tick. When a network has several endpoints, a tick that fails for RPC reasons tries the next one; a revert or an undecodable return is a fact about the bytecode, so it is reported rather than retried elsewhere.

## Schedules

A schedule is a six-field cron expression, seconds first, evaluated in UTC. Six fields rather than the usual five because minute resolution cannot express "about every block", which is the cadence this feature exists for. A five-field expression pasted from a crontab is rejected rather than reinterpreted, and an expression that names no real moment, such as the 31st of February, is refused at install time instead of displaying a next run that never arrives.

| Expression       | Meaning             |
| ---------------- | ------------------- |
| `*/12 * * * * *` | roughly every block |
| `0 */5 * * * *`  | every five minutes  |
| `0 0 * * * *`    | hourly, on the hour |
| `0 30 13 * * *`  | daily at 13:30 UTC  |

Schedules are UTC because a local-time schedule has to answer what happens to an 02:30 job during a daylight-saving transition. Write the UTC hour you mean.

**Missed ticks are skipped, never backfilled.** If the application was closed, the wallet was locked, or the machine was asleep across ten fire times, the automation runs once at the next tick rather than ten times in a row. Every tick derives its calls from live chain state, so a backlogged tick would be acting on an intent computed for a chain that no longer exists.

**One transaction is in flight at a time per wallet and network.** A tick that arrives while this automation's own last transaction is still settling, or while any other send holds that wallet and network, is skipped with the reason recorded. It is skipped rather than queued, for the same reason: the next scheduled tick recomputes from scratch. Several automations on one wallet and network are scheduled independently but share that single slot, so the ones that lose it record honestly that it was taken instead of stacking up.

Very frequent expressions are therefore self-limiting. An automation asking to fire every second is polled at most once a second, and while a transaction it sent is still settling, its ticks skip.

For a per-block cadence, a network configured to treat a transaction as settled after a single confirmation lets the next tick proceed sooner. The exposure that accepts is that a reorg can un-mine the transaction the next tick was planned on top of; bytecode that re-derives its intent from live state every tick self-corrects when that happens. A network carrying reviewed transfers may prefer a deeper confirmation setting.

Owners running automations should also set the network's maximum fee per gas. It bounds what a dishonest endpoint can cost an unreviewed automatic send, and automations add no separate fee cap of their own.

## Installing one

An authorized agent installs an automation directly, without an owner confirmation step, for the reason above: an automation cannot exceed the authority the owner already granted through the policy. What an install must do is name the policy revision it was written for. Naming a revision that is no longer active is refused outright, so an automation is never bound to a policy the agent did not read.

Installs are idempotent under a caller-chosen key that is unique per wallet. Installing again under an existing key replaces that automation rather than adding a second one, which makes retrying a timed-out install safe and is also how new bytecode, a new config, or a new schedule ships for the same job. Replacement clears the failure count, the stopped reason, and the record of the last transaction, because those described bytecode that is no longer installed.

A `config` byte string is stored alongside the bytecode and passed to `automate` on every tick. It exists so one compiled blob serves many parameterizations, such as an address, a threshold, or a pool identifier, without recompiling.

## Bound to one wallet, one network, one policy revision

Every automation records the policy revision that was active when it was installed. A tick reads the current revision first, and if it does not match, the automation does not run. It has not failed; it moves to **awaiting relink** and waits for the owner to look at it again.

The threat this closes is one that only appears later. An automation whose calls the policy rejects stops, which is correct and visible. But if the owner then widens the policy for some unrelated reason, a design that only checked the policy at send time would silently re-arm that stopped job, now authorized by a rule written for something else entirely. Nobody decided that. Binding to the revision makes re-arming an explicit act, which is also why the binding is to the whole revision rather than to the particular rules an automation happens to touch: narrowing it would be a guess about which edits matter.

An automation is likewise bound to one wallet and one network. It does not follow a key imported elsewhere, and there is no operation that moves one between wallets or chains. Bytecode is network-specific in two independent ways, since both the addresses it references and the EVM features it was compiled for belong to a particular chain.

## Why an automation stops

Nothing retries. Every terminal disappointment stops the automation and records why, because bytecode that emitted a reverting or disallowed call will emit it again on the next tick, and stopping is the only response that does not burn gas or fill the approval queue in a loop.

| Reason                                                                  | State           |
| ----------------------------------------------------------------------- | --------------- |
| The policy did not allow every call, or the batch's simulation failed   | disabled        |
| The batch reverted on chain                                             | disabled        |
| The batch did not mine within 30 minutes                                | disabled        |
| Ten consecutive failed ticks (RPC error, revert, or undecodable return) | disabled        |
| The owner pressed **Stop**, or an agent disabled it                     | disabled        |
| The signing policy revision changed                                     | awaiting relink |

When a policy rejects the batch, the request that was left waiting for review is the diagnostic: it shows exactly which call the policy did not permit. Exactly one such request survives, rather than one per tick, precisely because the automation stops.

To start a stopped automation again, use **Run again** in the Automations tab, which rebinds it to the current policy revision after showing what it is. An agent can also reinstall it under the same key, which replaces the bytecode and restarts it against the active revision. There is no separate re-enable operation for an agent, so restarting always states exactly what will run.

## The Automations tab

Each automation appears as a card carrying its name, the account it spends from, and its network; its schedule and next run time in UTC; and, when it has stopped, the reason first, because that is the only thing on the screen the reader has to act on. Below that are the outcome of the last run and the automation's identity: the keccak256 hash of its bytecode, the bytecode's size in bytes, the policy revision it is bound to, and its key.

The tab cannot show what bytecode does. It shows the hash, which is what an owner can compare against the hash the agent that compiled it reported.

Every tick is appended to that automation's run history, including the quiet ones that found nothing to do and the ones that skipped. A log that kept only eventful runs could not tell a quiet automation from a stopped one, which is usually the distinction a reader came for. The history is capped per automation and trimmed oldest first.

A run that produced a transaction links straight to that transaction's ordinary detail view. That link keeps working however long ago the run happened, because clearing activity history hides those records rather than deleting them: a hidden record is absent from every list and still opens by reference. The per-wallet history cap likewise skips any record an automation run points at. The cap exists to bound storage, not to break the record of what the wallet did while nobody was watching.

Owner controls are **Stop** on a running automation and **Run again** on a stopped one.

## Writing one

The wallet does not compile anything and has no opinion about the source language. It takes deployed runtime bytecode as hex, which is a compiler's `deployedBytecode` rather than its creation `bytecode`. Handing over creation code is the most common first mistake, since the wallet never runs a constructor and never deploys anything.

An agent connected over [MCP](/wallet/agents/) has four tools — install, list, disable, and dry run — and a bundled skill at `wallet://skills/write-ekubo-automation/SKILL.md` that carries the interface, the rules below, and worked Solidity examples. The skill is the authoring reference; what follows is why the rules exist.

The dry-run tool is the compile-test-fix loop. It runs bytecode once against live chain state without installing, scheduling, signing, or storing anything, and reports the calls it returned, the full simulation of the batch those calls become, the policy findings that decide whether the batch could send automatically, and, on failure, the revert selector, a decoded `Error(string)` or `Panic(uint256)`, and the raw return bytes. Given a cron expression it also validates it and shows the next few times it would fire. Dry-running before installing is what prevents the most common broken automation: one whose calls the active policy was never going to allow, which stops on its first tick.

Four constraints follow from where the code runs, and each produces a bug that looks like nothing else:

- **Declare no state variables.** The code runs at the wallet's address, so `SLOAD` reads the wallet's storage at the delegated account implementation's layout, not the contract's own. Use `constant` values or read parameters out of `config`.
- **No `immutable` values, no constructor, no external libraries.** All three leave unresolved placeholders in a deployed-bytecode artifact. Internal libraries inline and are fine.
- **There is no memory between ticks.** Every write is discarded, so a counter, a cursor, or a "last run" timestamp has to be derived from chain state the bytecode can read: the effect of its own previous transaction, a timestamp the target contract stores, a balance that changed.
- **Receiver hooks and ERC-1271 do not answer during the poll.** The state override replaces the wallet's code for the duration of the tick, so a contract that calls back into the wallet reaches the automation's dispatcher instead of the account implementation. Probing such a call requires answering those selectors, or delegating to the canonical implementation for anything unhandled. This affects the poll only; the batch the wallet sends executes through the intact delegation.

Because the poll's writes are thrown away, probing is the intended pattern rather than a workaround. Bytecode is free to perform the state-changing call it is considering, inspect the result, and emit it only if the result clears a threshold.

## Limits

| Limit                                     | Value          |
| ----------------------------------------- | -------------- |
| Bytecode                                  | 49,152 bytes   |
| Config                                    | 8,192 bytes    |
| Name and key                              | 120 characters |
| Automations per wallet and network        | 32             |
| Calls returned by one tick                | 4,096          |
| Calldata across one batch                 | 8 MiB          |
| Run records kept per automation           | 2,000          |
| Consecutive failed ticks before it stops  | 10             |
| Time a sent batch may go unmined          | 30 minutes     |
| Time one tick's RPC conversation may take | 20 seconds     |

The call and calldata limits are the execution plan's own, not a second set, so a batch this rejects is one the plan would have rejected a moment later.
