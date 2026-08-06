---
description: >-
  How Ekubo V3 extensions compare to Uniswap v4 hooks, and why one primitive —
  forward — replaces an entire category of hook machinery
---

# Extensions vs. Uniswap v4 hooks

Ekubo V3 and Uniswap v4 look similar from a distance: both are singleton AMMs with flash accounting, and both let a pool bind custom logic — an [extension](extensions.md) or a hook — as an immutable part of its pool key, with the set of lifecycle callbacks encoded in the logic contract's mined address. The designs diverge in how that custom logic is allowed to act, and the difference is most visible when you try to build behavior that is *outside* the scope of a concentrated liquidity AMM: new order types, reward schedules, RFQ fills, staking and emissions, wrappers.

## Lifecycle callbacks: notifications, not plumbing

Ekubo has eight [call points](extensions.md#immutability): before and after pool initialization, swaps, position updates, and fee collection. Every one of them is a plain notification — extension callbacks return nothing. An extension that wants to move funds doesn't hand deltas back to Core through its return value; it re-enters Core inside the same lock, as an ordinary participant, and the [flash accounting](architecture.md#the-till-pattern) guarantees everything nets to zero before the lock closes.

Uniswap v4 has ten hook callbacks governed by **fourteen** permission flags, because four of them come in an extra "returns delta" variant. A [v4 hook](https://github.com/Uniswap/v4-core/blob/v4.0.0/src/interfaces/IHooks.sol) communicates through its return values: each callback returns its own selector as a validity check, `beforeSwap` additionally returns a `BeforeSwapDelta` (with sign conventions over "specified" and "unspecified" currencies) plus an LP fee override (a `uint24` that is only honored when the pool is dynamic-fee and a particular bit is set), and every `PoolManager` operation carries a `hookData` bytes parameter so callers can smuggle arguments through to the hook. All of that plumbing sits in the hot path of every swap, whether a pool uses it or not.

Ekubo needs none of it, because custom behavior doesn't flow through callback return values at all.

## `forward`: custom behavior as a first-class citizen

Ekubo's answer to "I want my pool to do something the AMM doesn't do" is a single primitive on the flash accountant:

```solidity
function forward(address to) external;
```

Any locker can forward its lock context to any contract. For the duration of the call, the forwardee *becomes* the locker: it can swap, update positions, save balances, accumulate fees — any Core operation — all charged against the original lock and settled once at the end. Extra calldata is passed through raw, return data comes back raw, and reverts bubble up. The whole mechanism is [about thirty lines of assembly](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/base/FlashAccountant.sol); the receiving side is a [one-function abstract contract](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/base/BaseForwardee.sol). A forwardee defines its own ABI — nothing has to be dressed up as a swap or squeezed through `hookData` bytes — and because the forwardee inherits the caller's lock, "the user pays for it" falls out of the accounting for free: whatever the forwardee spends becomes a debt the original locker must settle.

## What's been built with it

Every extension below is deployed and live. Together they exercise the full design space, and each one is the best illustration of a specific capability.

### Oracle — pure observation, call points alone

The [Oracle](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/extensions/Oracle.sol) never uses `forward` at all. `beforeInitializePool` validates the pool's shape (paired against native ETH, zero fee, full range), and `beforeSwap` / `beforeUpdatePosition` insert a time-weighted snapshot just before the price or liquidity changes. Void notifications are all an oracle needs — there is no delta to return, so none of v4's return-value plumbing would have been exercised.

### TWAMM — a new order type with its own ABI

[TWAMM](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/extensions/TWAMM.sol) uses both halves of the design. Its call points make time-execution invisible to everyone else: before any swap, position update, or fee collection it executes pending virtual orders (opening its own nested lock to do so), so every interaction sees a pool state as if DCA orders had been trading continuously. Placing or modifying an order, and collecting its proceeds, happens through `forward`: the [Orders periphery](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/Orders.sol) forwards an order key and sale-rate delta in TWAMM's own encoding, and the tokens the order sells are simply debts on the forwarding lock. An order placement is not a swap, and here it never has to pretend to be one — in v4 the equivalent must be expressed as an intercepted `swap()` whose `beforeSwap` consumes the delta via custom accounting, with the real parameters packed into `hookData`.

### Boosted fees — scheduling rewards through the lock

[BoostedFees](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/extensions/BoostedFees.sol) shows that `forward` is not only for trading. Anyone — an incentives program, a token team — forwards `(poolKey, startTime, endTime, rate0, rate1)` to schedule a TWAMM-style stream of extra fee rewards into a pool. The extension computes the total cost and books it against the scheduler's lock as saved balances; the funding settles with everything else when the lock closes. Its call points then drip the accrued boost into the pool as fees before every swap, position update, and fee collection. One forwarded call both *prices* and *collects payment for* a scheduled future action — no separate deposit flow, no token approvals to the extension.

### MEV capture — owning the swap path

[MEVCapture](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/extensions/MEVCapture.sol) rejects direct swaps: `beforeSwap` reverts with `SwapMustHappenThroughForward`. Swappers forward to the extension, which performs `CORE.swap` itself and then charges an additional fee proportional to how many tick spacings the price has moved within the current block — captured value that is paid back to the pool's liquidity providers via `accumulateAsFees`. This is a dynamic fee model expressed as ordinary Solidity around a swap call, with no dynamic-fee pool flag, no fee-override bit encoding, and no delta sign conventions.

### Ve33 — an entire protocol behind one forwardee

[Ve33](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/extensions/Ve33.sol) is the strongest stress test of the model: a complete [ve(3,3) system](../products/ve33.md) — staking, vote-directed emissions, voter-set swap fees, reward claims — lives behind a single `handleForwardData` that multiplexes six call types: swap (with the vote-chosen fee accounted to voters), stake, unstake, claim LP rewards, claim voter pool fees, and schedule emissions. The forwarded `original` locker doubles as the authenticated owner for staking and claiming, so authorization comes from the lock context itself. Call points do the AMM-shaped bookkeeping: validating pool configuration, snapshotting range-aware reward accounting before liquidity changes, and rejecting direct swaps so fees can't be bypassed. In v4 this would be several hooks, external manager contracts, and custom accounting; here it is one extension.

### Signed exclusive swaps — RFQ fills as a pool

[SignedExclusiveSwap](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/extensions/SignedExclusiveSwap.sol) turns a pool into an [RFQ venue](../integration-guides/signed-exclusive-swaps.md): pools carry zero base fee, and every swap must arrive through `forward` carrying a controller-signed payload that sets that specific swap's fee, bounds, deadline, and nonce. The extension verifies the signature and executes against Core. Off-AMM, quote-driven liquidity — the very thing v4's custom accounting exists for — implemented as signature checks around a swap call.

### Wrappers — `forward` without being an extension

[TokenWrapper](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/TokenWrapper.sol) and [SavedBalancesWrapper](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/SavedBalancesWrapper.sol) attach to no pool, register no call points, and are not extensions at all — they simply receive forwarded lock contexts to wrap tokens or tokenize saved balances mid-lock. `forward` is a general composition primitive of the settlement layer, not a pool feature; in v4 there is no analogue, because hooks exist only as pool configuration.

Routing over all of this stays uniform: the production [Router](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/Router.sol) needs one branch — if a pool's extension takes over swaps, `forward` to it, otherwise call `swap` directly — and either way the route composes inside one lock with one net settlement.

## Case study: "aggregator hooks"

A category of v4 hook worth examining is the *aggregator hook*: a hook that fills swaps against external liquidity — other pools, other venues, off-chain inventory — so that a v4 pool behaves like an aggregator, pitched as giving integrators one pool that routes everywhere.

This is machinery in the wrong layer:

* **Aggregation is already a solved router problem.** Finding the best split across venues is off-chain computation; executing it is batching calls — precisely what a router contract does. Many aggregators do exactly this in production today, and do it more gas-efficiently than a hook can: the router calls each venue directly, with no `PoolManager` dispatch, no hook permission checks, and no custom-accounting delta translation wrapped around every fill.
* **What remains is rent collection.** Strip away the routing (done better off-chain) and the execution (done cheaper in a router), and the hook's remaining function is to insert a toll for the hook's beneficiaries — in Uniswap's case, a fee path for its tokenholders. But a fee is the one thing that genuinely is trivial to implement in a router contract, so the hook code is superfluous even for that purpose.
* **There is no distribution advantage.** A custom-accounting hook changes a pool's quoting and settlement semantics, so aggregators and solvers must still integrate that specific hook, one by one — the same per-venue effort as integrating any new protocol. Deploying as "a v4 pool" does not make existing integrations pick it up automatically; it just makes the integration target more complicated and the execution more expensive.

Ekubo draws the layer boundary the other way. Core is ownerless and charges no protocol fee; extensions change what a *pool* is, and aggregation across pools and venues lives where it is cheap — in [router contracts](../integration-guides/yul-router.md) and [aggregator integrations](../integration-guides/aggregators.md). Where off-AMM liquidity is genuinely useful, it appears as a pool type built on `forward` — [signed exclusive swaps](../integration-guides/signed-exclusive-swaps.md) give RFQ market makers a venue that every router and aggregator can fill against like any other Ekubo pool.

## Summary

| | Ekubo V3 extensions | Uniswap v4 hooks |
| --- | --- | --- |
| Lifecycle callbacks | 8 call points, all void notifications | 10 callbacks, 14 permission flags, selector + delta returns |
| Moving funds | Re-enter Core inside the lock, like any participant | Return `BeforeSwapDelta` / `BalanceDelta` from callbacks |
| Custom behavior beyond the AMM | `forward` — take over the lock, define your own ABI | Custom accounting — express it as an intercepted `swap()` with `hookData` |
| Passing arguments | Raw calldata through `forward` | `hookData` bytes threaded through every `PoolManager` call |
| Paying for extension actions | Debts on the forwarding lock, settled once | Token transfers / ERC-6909 flows arranged per hook |
| Non-pool integrations | Any contract can be a forwardee, no registration | N/A — hooks exist only as pool configuration |
| Protocol fee | None; Core is ownerless | Governance-set protocol fee in Core, up to 0.1% per direction |
