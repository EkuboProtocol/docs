---
description: Frequently asked questions
---

# FAQ

<details>

<summary>What is Ekubo?</summary>

Ekubo is an [automated market maker](introduction/key-concepts.md#automated-market-maker-amm) built for [Starknet](introduction/key-concepts.md#starknet).

</details>

<details>

<summary>What is an AMM?</summary>

[Automated market makers](introduction/key-concepts.md#automated-market-maker-amm) connect liquidity providers and swappers, so market makers can earn fees with their capital and swappers can swap.

Liquidity providers are people with assets that want to do market making by creating positions, e.g. position to buy & sell ETH with a 5 bips fee between the prices of $1500 and $2000. This position will buy 5 bips below mid price and sell 5 bips above mid price until it runs out of assets.

Swappers are people who want to trade, e.g. buy 100 USDC worth of ETH.

Automated market makers are the financial glue that brings these people together.

</details>

<details>

<summary>What is Starknet?</summary>

[Starknet](introduction/key-concepts.md#starknet) is a [layer 2](introduction/key-concepts.md#layer-2) on [Ethereum](introduction/key-concepts.md#ethereum) that uses ZK proofs to provide a scalable decentralized platform for composable applications. Check out the [key concepts](https://docs.ekubo.org/introduction/key-concepts) section to learn more.

</details>

<details>

<summary>What wallets can I use on Starknet?</summary>

As of August 2023, you can use [Argent X](https://www.argent.xyz/argent-x/) or [Braavos](https://braavos.app/).

</details>

<details>

<summary>Will there be a token?</summary>

We currently have no plans for a token. However, we recognize the withdrawal protocol fee collected by the protocol should be returned to the users and will explore ways to do so.

</details>

<details>

<summary>What makes Ekubo protocol unique?</summary>

Ekubo is the first AMM on Starknet to feature **any of** concentrated liquidity, extensibility and the [singleton design / "till" pattern](https://github.com/OpenZeppelin/openzeppelin-contracts/issues/4361#issue-1760901388).

</details>

<details>

<summary>Will the code be open source?</summary>

We are interested in open sourcing the code long-term, but in the short term there are many competitors building AMMs on Starknet with a foothold in the market. In order to get a foothold in this market, the contracts will remain closed source for now. If you are interested in integrating and need access to the code, please email us at eng@ekubo.org

</details>

