---
description: Frequently asked questions
---

# ❓ FAQ

<details>

<summary>What is Ekubo Protocol?</summary>

Ekubo is an [automated market maker](../integration-guides/reference/key-concepts.md#automated-market-maker-amm) built for [Starknet](../integration-guides/reference/key-concepts.md#starknet), with several unique [features](features.md) including concentrated liquidity and a extensible and gas efficient architecture.

</details>

<details>

<summary>What is an AMM?</summary>

[Automated market makers](../integration-guides/reference/key-concepts.md#automated-market-maker-amm) connect liquidity providers and swappers, so market makers can earn fees with their capital and swappers can swap.

Liquidity providers are people with assets that want to do market making by creating positions, e.g. position to buy & sell ETH with a 5 bips fee between the prices of $1500 and $2000. This position will buy 5 bips below mid price and sell 5 bips above mid price until it runs out of assets.

Swappers are people who want to trade, e.g. buy 100 USDC worth of ETH.

Automated market makers are the financial glue that brings these people together. Read more in the [key concepts](../integration-guides/reference/key-concepts.md) section.

</details>

<details>

<summary>What is Starknet?</summary>

[Starknet](../integration-guides/reference/key-concepts.md#starknet) is a [layer 2](../integration-guides/reference/key-concepts.md#layer-2) on [Ethereum](../integration-guides/reference/key-concepts.md#ethereum) that uses ZK proofs to provide a scalable decentralized platform for composable applications. Check out the [key concepts](https://docs.ekubo.org/introduction/key-concepts) section to learn more.

</details>

<details>

<summary>What wallets can I use on Starknet?</summary>

As of August 2023, you can use [Argent X](https://www.argent.xyz/argent-x/) or [Braavos](https://braavos.app/).

</details>

<details>

<summary>Is there an Ekubo token?</summary>

Yes, there is an EKUBO token. You can find the address on the [contract-addresses.md](../integration-guides/reference/contract-addresses.md "mention") page.

</details>

<details>

<summary>What makes Ekubo protocol unique?</summary>

Ekubo is the first AMM on Starknet to feature **any of** concentrated liquidity, extensibility and the [singleton design / "till" pattern](https://github.com/OpenZeppelin/openzeppelin-contracts/issues/4361#issue-1760901388). Read more about its features [here](features.md).

</details>

<details>

<summary>Will the code be open source?</summary>

We are interested in open sourcing the code long-term, but in the short term there are many competitors building AMMs on Starknet with a foothold in the market. In order to get a foothold in this market, the contracts will remain closed source for now. If you are interested in integrating and need access to the code, please email us at eng@ekubo.org

</details>

<details>

<summary>What does "Ekubo" mean?</summary>

"Ekubo" is a reference to the character [Dimple](https://mob-psycho-100.fandom.com/wiki/Dimple) from the anime [Mob Psycho 100](https://en.wikipedia.org/wiki/Mob_Psycho_100).

</details>
