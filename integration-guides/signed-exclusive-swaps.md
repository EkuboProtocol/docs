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
* Signatures are one-time-use, via nonce replay protection
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
2. The extension validates the deadline, the locker authorization, that the nonce is unused, and the signature against the pool's stored controller.
3. If this is the first touch of the pool in the block, previously collected extension fees are donated to LPs.
4. The extension calls `Core.swap(...)`.
5. The signed `fee` is applied to the result — charged on the output for exact-in swaps, on the required input for exact-out.
6. The resulting balance update is checked component-wise against `minBalanceUpdate`.
7. The charged fee is stored in Core saved balances under the extension owner.

## Why `minBalanceUpdate` matters

`minBalanceUpdate` is a signed lower bound on both components of the final balance update, and it is part of the signed payload. One field gives the signer four protections at once:

* **Direction enforcement** — requiring the expected leg to be positive or negative prevents a fill that moves value the wrong way
* **Slippage tolerance** — the signer can allow a range ("at least X output") rather than an exact result
* **Maximum magnitude** — bounds cap how large a trade can execute under one signature
* **Best-price cap** — because both components are bounded, the signer can also cap how *favorable* a fill may be, avoiding overfilling beyond inventory or risk limits

## Fee donation timing

Collected fees are not donated to LPs immediately. On the first touch of a pool in a new block — a swap, a position update, or a fee collection — the extension donates previously collected fees into LP accounting and marks the pool as updated for that block. This prevents same-block liquidity from being added purely to capture fees earned in earlier blocks.

## Replay protection and nonce management

Each signed quote carries a nonce that can be consumed only once. Managing the nonce lifecycle is the controller's responsibility off-chain: track which nonces were consumed on-chain, which were issued but expired unfilled, and only recycle a nonce when it is safe to do so. The owner can reset nonce state through admin bitmap management when controlled recycling is needed.

## Quote selection risk

Off-chain signed quotes carry selective execution risk: a counterparty can request many quote variants, wait for the market to move, and execute only the profitable ones while letting the rest expire. Common mitigations:

* Use short deadlines so stale quotes lose value quickly
* Bind quotes to an authorized locker or session
* Gate quote access so only qualified users receive exclusive-liquidity quotes
* Apply stricter issuance policies — rate limits, narrower bounds, per-user controls — to higher-risk flow

## Controller management

The extension is `Ownable`. The owner initializes each pool with a controller address via `initializePool(poolKey, tick, controller)`; direct initialization through Core is blocked. The controller for an already-initialized pool can be updated by the owner. Controller signatures work for both EOAs and ERC-1271 contract wallets — the EOA-versus-contract flag is encoded in the high bit of the controller address.
