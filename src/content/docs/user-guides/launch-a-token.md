---
description: >-
  Launch a new token in a single Ekubo pool with no seed capital, and what
  creators and buyers should know about its creator fee and locked liquidity.
title: "Launch a token"
---

A launch creates one new ERC-20 token and places its whole supply in a single Ekubo pool against a quote token, either native ETH or an ERC-20. The supply sits in one position that holds only the new token, from a start price up to an upper price. The creator does not need any seed capital: buyers provide all of the quote token in the pool.

Launches use the zero-seed launch extension, deployed on [Robinhood Chain](#contracts). You can launch a token in the [interface](https://ekubo.org/launches/new), which creates tokens with 18 decimals.

## How a launch works

Creating a launch deploys the token, mints its supply straight into the pool's position and gives up the token's mint authority in the same transaction, so nobody can mint more later. The position is owned by the extension, and the pool accepts no other positions.

The creator chooses a trading start time. It cannot be in the past when the launch is created, and every swap before it reverts, so nobody can buy early. The interface accepts a start between 5 minutes and 24 hours from now.

Buying moves the price up from the start price. Selling moves it back down, but never below the start price, because no liquidity exists below it. If every token is sold to buyers, the price reaches the upper price and buys stop until someone sells.

A rounding remainder of a few base units that does not fit the position is minted to the zero address, so the total supply still equals the amount requested.

## The creator fee

The pool itself charges no swap fee. Instead, every swap pays a creator fee to the launch owner. The fee is charged on the side the swap calculates: on the tokens received when you specify the amount you pay, and on the amount paid when you specify the amount you receive. Creator fees can therefore accrue in either token.

The fee starts at an initial rate and decays towards a final rate, which is a floor. The part above the final rate halves every half-life, starting at the trading start time. The fee approaches the final rate rather than reaching it on a schedule.

| Setting       | Interface default |
| ------------- | ----------------- |
| Initial fee   | 50%               |
| Final fee     | 0.3%              |
| Fee half-life | 1 day             |

With these defaults the fee is about 25.2% after one day, 12.7% after two days and 0.7% after a week. On-chain the decay speed is a rate in ticks per second rather than a half-life, so a half-life converts to the nearest rate and the times are approximate. You can read the current rate of any launch with `feeAt(poolId, timestamp)` on the extension.

### Claiming and transferring fees

The account that created a launch through the periphery contract is its owner. Only the owner can call `claimFees(poolKey, recipient)` on the periphery, which sends all accrued creator fees in both tokens to `recipient`. The owner can hand the launch, including unclaimed and future fees, to another address with `transferLaunch(poolId, newOwner)`. `launchOwner(poolId)` returns the current owner.

## After the launch

The pool and its position stay in place forever. The extension has no admin, upgrade, withdrawal or migration path, and the position changes only through swaps. The quote tokens buyers pay stay in the position as liquidity for sellers: nobody can withdraw them, including the creator. The creator's only income is the creator fee.

## Risks

The decaying fee is not a fair-launch guarantee. Anyone can buy as soon as trading starts, including bots and the launch owner. A high initial fee makes early buys expensive for everyone, but the owner receives the fee on its own buys, so it does not protect other buyers from the owner.

An ERC-20 quote token must be trusted. Ekubo keeps one balance per token across all pools, so a quote token that misreports balances or transfers can drain every pool and fee balance that holds it, including other launches and ordinary pools. Only launch against a plain ERC-20 with no transfer fees, rebasing, callbacks, pausing, blocklists or upgrades. Native ETH has no such risk.

The interface picks a tick spacing that keeps the whole price range to at most 1,024 spacings, so one buy can move through the entire range.

## Contracts

| Chain                           | Contract  | Address                                      |
| ------------------------------- | --------- | -------------------------------------------- |
| Robinhood Chain (chain ID 4663) | Extension | `0x51bDfB5aB2076B5220B5067Ac29167a56147a139` |
| Robinhood Chain (chain ID 4663) | Periphery | `0x80b13D3E2615D6bba412F98D12347B2FfAC0f6Ae` |

The source is in [`ZeroSeedLaunch.sol`](https://github.com/EkuboProtocol/evm-contracts/blob/3d6378f585591dc7eabeea6976932c30524bb8ea/src/extensions/ZeroSeedLaunch.sol) and [`ZeroSeedLaunchPeriphery.sol`](https://github.com/EkuboProtocol/evm-contracts/blob/3d6378f585591dc7eabeea6976932c30524bb8ea/src/ZeroSeedLaunchPeriphery.sol).
