---
description: >-
  RFQ-style exclusive liquidity on Ekubo: an extension where a controller signs
  each swap off-chain with its own fee and bounds
---

# Signed exclusive swaps

`SignedExclusiveSwap` is an [extension](../concepts/extensions.md) that makes a pool tradeable **only** through off-chain signed quotes. A designated *controller* signs each swap, setting a per-swap fee and bounds on the result. This gives market makers and aggregators an RFQ-style venue that still settles in Ekubo Core, reusing its liquidity math, routing, and [flash accounting](../concepts/architecture.md).

The extension is forward-only: direct swaps against the pool revert. Every swap must arrive through `Core.forward(...)` carrying a valid signature.

Source: [`SignedExclusiveSwap.sol`](https://github.com/EkuboProtocol/evm-contracts/blob/main/src/extensions/SignedExclusiveSwap.sol) · [integration guide](https://github.com/EkuboProtocol/evm-contracts/blob/main/signed-exclusive-swap-extension.md) · [scoped review](https://github.com/EkuboProtocol/evm-contracts/blob/main/audits/SignedExclusiveSwap-Extension-Audit.md)

## What the extension enforces

* Direct swaps are blocked; swaps must be forwarded with a signed payload
* Signatures are one-time-use, via a nonce bitmap — with one reserved exception (see [Replay protection](#replay-protection-and-nonce-management))
* A signature can optionally restrict which locker may use it
* The pool's own fee must be zero — all fee logic lives in the signature
* Pools must be initialized through the extension's owner-only `initializePool(...)`
* Signed fees are collected by the extension and donated to LPs on the next block touch

## The signed payload

A forward call decodes five values: the `poolKey`, the swap `params`, a `meta` word, a `minBalanceUpdate` word, and the `signature`.

`SignedSwapMeta` packs four fields into one 256-bit word:

| Field | Width | Meaning |
| --- | --- | --- |
| `deadline` | 32 bits | Signature expiry |
| `fee` | 32 bits | Q32 fee rate applied to this swap |
| `nonce` | 64 bits | One-time-use replay protection |
| `authorizedLockerLow128` | 128 bits | Lower 128 bits of the permitted locker; `0` means any locker |

The signature is EIP-712 over:

```
SignedSwap(bytes32 poolId,uint256 meta,bytes32 minBalanceUpdate)
```

where `poolId = keccak256(abi.encode(poolKey.token0, poolKey.token1, poolKey.config))`. The domain is `Ekubo SignedExclusiveSwap`, version `1`, bound to the chain ID and the extension address.

With [`@ekubo/yul-router-sdk`](yul-router.md), `encodeSignedSwapMeta({ deadline, fee, nonce, authorizedLocker })` packs the meta word and `encodePoolBalanceUpdate(delta0, delta1)` packs the bounds.

## Swap flow

1. The caller holds a Core lock and forwards to the extension.
2. The extension validates the deadline (which must also be no further than 30 days out), the locker authorization, and the signature against the pool's stored controller.
3. If this is the pool's first touch at the current block timestamp, previously collected extension fees are donated to LPs.
4. The extension calls `Core.swap(...)`.
5. The balance update returned by Core is checked component-wise against `minBalanceUpdate`. **This check happens before the fee is applied**, so the bound constrains the raw swap result, not the amount the swapper finally receives.
6. Only now is the nonce consumed — deliberately after the bounds check, so a swap that fails its bounds costs less gas and does not burn the nonce.
7. The signed `fee` is applied — charged on the output for exact-in swaps, on the required input for exact-out — and the fee-adjusted balance update is returned to the caller.
8. The charged fee is credited to the **extension contract's own** saved balance in Core, salted by the pool ID, from which it is later donated to that pool's liquidity providers.

## Why `minBalanceUpdate` matters

`minBalanceUpdate` is a signed lower bound on both components of the final balance update, and it is part of the signed payload. One field gives the signer four protections at once:

* **Direction enforcement** — requiring the expected leg to be positive or negative prevents a fill that moves value the wrong way
* **Slippage tolerance** — the signer can allow a range ("at least X output") rather than an exact result
* **Maximum magnitude** — bounds cap how large a trade can execute under one signature
* **Best-price cap** — because both components are bounded, the signer can also cap how *favorable* a fill may be, avoiding overfilling beyond inventory or risk limits

## Fee donation timing

Collected fees are not donated to LPs immediately. On a pool's first touch at a new block *timestamp* — a swap, a position update, or a fee collection — the extension donates previously collected fees into LP accounting and records the timestamp. This prevents liquidity from being added purely to capture fees earned earlier. Note the gate is the block timestamp, not the block number, so on chains that can produce more than one block per second donation happens at most once per second.

## Replay protection and nonce management

Each signed quote carries a nonce that can be consumed only once, tracked in a bitmap. Managing the lifecycle is the controller's responsibility off-chain: track which nonces were consumed on-chain, which were issued but expired unfilled, and only recycle a nonce when it is safe to do so. The owner can reset nonce state through admin bitmap management when controlled recycling is needed.

{% hint style="warning" %}
The nonce `type(uint64).max` is a **reserved, reusable sentinel**: it is never consumed, so a signature carrying it can be replayed without limit until its deadline passes. Issue it only when unlimited reuse within the deadline is exactly what you intend.
{% endhint %}

## Quote selection risk

Off-chain signed quotes carry selective execution risk: a counterparty can request many quote variants, wait for the market to move, and execute only the profitable ones while letting the rest expire. Common mitigations:

* Use short deadlines so stale quotes lose value quickly
* Bind quotes to an authorized locker or session
* Gate quote access so only qualified users receive exclusive-liquidity quotes
* Apply stricter issuance policies — rate limits, narrower bounds, per-user controls — to higher-risk flow

## Controller management

The extension is `Ownable`. The owner initializes each pool with a controller address via `initializePool(poolKey, tick, controller)`; direct initialization through Core is blocked. The controller for an already-initialized pool can be updated by the owner. Controller signatures work for both EOAs and ERC-1271 contract wallets, and which path is used is determined by **bit 159 of the controller address itself**, not by a separate flag: addresses below `2^159` are verified as EOAs via ECDSA, addresses at or above it via ERC-1271. Initialization and controller updates enforce that the address's code presence matches, so an EOA whose address happens to have bit 159 set cannot be used as a controller.
