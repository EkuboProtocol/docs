---
description: >-
  Liquidity incentive campaigns, how rewards are measured, and the on-chain
  drop infrastructure used to distribute them
---

# Rewards and incentives

Ekubo runs liquidity incentive campaigns that pay reward tokens to liquidity providers. Rather than paying for deposited value alone, campaigns measure the **depth a position actually provides near the market price**, so rewards track useful liquidity rather than parked capital.

Rewards accrue continuously and are distributed through periodic on-chain drops that you claim yourself.

## Campaigns

A campaign defines what is being rewarded and for how long: a chain, a reward token, a start and end time, the set of pairs included, and which lockers and extensions qualify. Campaigns are listed publicly:

```
GET https://prod-api.ekubo.org/campaigns?chainId={chainId}
```

Each campaign reports, per pair, the depth currently measured and the amounts `scheduled` and already `distributed`, along with a campaign-level `nextDropTime` — when the next drop is scheduled to land.

To see what a specific position has earned over a period:

```
GET https://prod-api.ekubo.org/rewards/{chainId}/{locker}/{salt}
```

Rewards are computed from the same on-chain event data served by the open source [indexer](indexer.md), so the measurement is reproducible from public data.

## Drops and claiming

Accrued rewards are published periodically as a **merkle drop**. Each drop commits to a merkle root covering every recipient and amount; claiming means presenting a proof against that root.

To find what an address can claim right now:

```
GET https://prod-api.ekubo.org/claims/{address}?chainId={chainId}
```

The [app](https://app.ekubo.org/rewards) turns these into one-click claims, but the claim is an ordinary on-chain call — nothing gates it.

### The Incentives contract

On EVM chains, drops are handled by a single [`Incentives`](https://github.com/EkuboProtocol/evm-contracts/blob/v3.2.0/src/Incentives.sol) contract — a singleton that hosts many independent airdrops at the deterministic address `0xC52D2656cb8C634263E6A15469588beB9C3Bb738` on every chain.

A drop is identified by its **drop key**: the owner, the reward token, and the merkle root. That means a drop is fully described by what it pays and who it pays — no registry, no per-drop deployment.

| Function | Who can call it | What it does |
| --- | --- | --- |
| `fund(key, minimum)` | Anyone | Tops the drop up to a minimum funded amount, pulling tokens from the caller |
| `claim(key, claimKey, proof)` | Anyone with a valid proof | Claims a recipient's allocation; each claim can only be made once |
| `refund(key)` | The drop owner | Returns whatever remains unclaimed |

Funding is permissionless: anyone can fund a drop, including third parties who want to add to a campaign. Claims are tracked in a bitmap so a claim cannot be replayed, and the contract is multicallable, so several claims can be batched into one transaction.

On Starknet, the equivalent role is played by the [`Airdrop`](https://github.com/EkuboProtocol/governance) contract in the governance repository, which uses the same merkle-proof approach and supports batched claims. It is what distributed the original [EKUBO token](../user-guides/ekubo-token.md) airdrop, and it has no claim deadline.

## Running your own campaign

Because both the campaign measurement data and the drop contract are public, incentive programs are not limited to the DAO:

* Compute allocations from indexed liquidity data — your own instance of the [indexer](indexer.md) is enough
* Publish a merkle root and fund the drop through `Incentives.fund(...)`
* Recipients claim against it permissionlessly; you can reclaim whatever goes unclaimed

For incentives that pay continuously rather than in periodic drops, the **boosted fees** extension streams externally funded rewards directly to a pool's LPs — see [Providing liquidity](liquidity.md), or [Ve33](ve33.md) if you want token holders to decide where those rewards go.
