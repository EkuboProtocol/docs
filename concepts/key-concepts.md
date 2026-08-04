---
description: The concepts behind Ekubo Protocol, and the platforms it runs on
---

# Key concepts

## Protocol concepts

### Automated Market Maker (AMM)

A decentralized finance protocol that lets users trade against pooled liquidity at algorithmically determined prices, allowing liquidity providers to automatically "buy low, sell high." AMMs differ primarily in the amount of customization available to liquidity providers. Depositing into an AMM is a bet that trading fees will outweigh the loss due to price divergence of the two assets in a pair.

### Constant product

The `x*y=k` formula that forms the basis of most AMMs, where `x` is the amount of one token (`token0`), `y` is the amount of the other (`token1`), and `k` is held constant as users trade with the pool. This formula is how trades are computed on Ekubo within regions of constant liquidity — see the [pool math](pool-math.md).

### Concentrated liquidity

The main feature that allows Ekubo to provide better pricing than other AMMs. In simple constant-product AMMs, deposited capital backs trading at every possible price — including unrealistic ones — so most of it sits unused. Concentrated liquidity lets each position specify the price range in which it is willing to trade. If you think ETH will only trade between 1800–2200 USDC, you can provide liquidity only in that range and deploy the rest of your capital elsewhere — or leverage up within the range to earn more fees (which also amplifies losses from price divergence).

**Capital efficiency** measures this leverage: how much more capital a full-range position would need to earn the same fees as a concentrated one.

### Ticks

Ticks are the discrete price points that can serve as position boundaries. Ekubo divides the price range logarithmically: tick `i` corresponds to the price `1.000001^i`, so each tick is 1/100th of a basis point — finer precision than most centralized limit order books. One-tick positions behave like limit orders, which makes Ekubo suitable as an on-chain order book.

**Tick spacing** is the minimum distance between ticks a pool's positions may use, specified per pool. Smaller tick spacing allows tighter ranges; larger tick spacing makes swaps cheaper to compute. Volatile pairs, where tiny price differences don't matter, are better served by a larger tick spacing.

### Flash accounting

All token balance accounting happens inside Ekubo before any tokens are transferred: you can trade with many pools and create or update many positions, then transfer only the net difference at the end (see the ["till" pattern](till-pattern.md)). Traditionally, each swap or position update settles immediately — even for multi-hop swaps within one transaction.

**Free flash loans** fall out of this design: you can `withdraw` tokens from the singleton and `deposit` them back in the same transaction without paying any fees.

## Platform concepts

### Ethereum

[Ethereum](https://ethereum.org/en/) is a blockchain that supports "smart contracts": autonomous programs that anyone can deploy and use. Ekubo Protocol V3 is deployed to Ethereum mainnet and many EVM-compatible networks — at the same contract addresses on every chain.

### Layer 2

A network that uses Ethereum to provide a more scalable platform without sacrificing decentralization or security. Sites such as [L2BEAT](https://l2beat.com/) track L2s and score them along multiple dimensions. Several of Ekubo's deployment chains (Arbitrum, Base, Optimism, Robinhood Chain, Starknet) are Ethereum L2s.

### Starknet

Starknet is a Layer 2 that scales Ethereum using STARK [zero-knowledge proofs](https://en.wikipedia.org/wiki/Zero-knowledge_proof), which let Ethereum verify the correctness of Starknet state transitions without re-executing every transaction. Starknet contracts are written in [Cairo](https://www.cairo-lang.org/), so ordinary Ethereum wallets are not compatible; wallets such as [Ready](https://www.ready.co/) and [Braavos](https://braavos.app/) work with Starknet. Ekubo's original deployment is on Starknet.
