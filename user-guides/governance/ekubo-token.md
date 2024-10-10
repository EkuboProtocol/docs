---
description: Information about the EKUBO token
---

# EKUBO token

The EKUBO token is an [L1 Ethereum token](https://etherscan.io/token/0x04C46E830Bb56ce22735d5d8Fc9CB90309317d0f) bridged to [Starknet](https://voyager.online/token/0x075afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87), developed for the purpose of decentralizing ownership of Ekubo Protocol.

### Initial distribution

The total supply of the EKUBO token is 10 million (`10,000,000`). The total supply was split into 3 equal parts of `3,333,333` tokens. The 3 categories of distribution for the EKUBO token generation event were:

* **Airdrop**: 1/3rd of the total supply was distributed to users via airdrop
* **Team**: 1/3rd of the total supply is held by the company Ekubo, Inc.
* **Sale**: 1/3rd of the total supply was sold by the DAO for ETH, USDC and STRK via Ekubo's DCA order feature

#### Airdrop

Each user's allocation of EKUBO was calculated based on their share of total points on the leaderboard, with a few adjustments: we exponentiated each user's points (i.e. `p^x`) based on their role in the ecosystem, and accounts that earned less than 1,000 points were excluded. As a result, users who used fewer accounts received slightly more EKUBO tokens from the airdrop.

* Moderators had a boost of `1.01`
* Active translators received a boost of `1.001`
* Everyone else received a boost of `1.0001`

The airdrop contract is deployed at the address `0x04bfacd0fcf70f444815de9150008fd12b5fb6721562707e502ce71ccb327d88` ([Starkscan](https://starkscan.co/contract/0x04bfacd0fcf70f444815de9150008fd12b5fb6721562707e502ce71ccb327d88), [Voyager](https://voyager.online/contract/0x04bfacd0fcf70f444815de9150008fd12b5fb6721562707e502ce71ccb327d88)). It uses the open source airdrop contract found [here](https://github.com/EkuboProtocol/governance/releases/tag/v2.2.1). There is no deadline to claim the airdrop.

An airdrop can be claimed by using a block explorer to submit a transaction using data found in this spreadsheet:

{% file src="../../.gitbook/assets/airdrop_data.csv.zip" %}
A CSV containing the entirety of the merkle tree for the EKUBO airdrop
{% endfile %}

#### Sale

The DCA orders executed over 2 months, starting 5/24/24, 2:48 AM UTC and ending 7/23/24, 7:09 PM. The proceeds of the DCA order were owned by the [Governor ](https://voyager.online/contract/0x053499f7aa2706395060fe72d00388803fb2dcc111429891ad7b2d9dcea29acd), a.k.a. the DAO.

The following pools were used: [EKUBO/ETH 5%](https://app.ekubo.org/positions/new?poolType=twamm\&quoteCurrency=ETH\&baseCurrency=EKUBO\&fee=17014118346046923173168730371588410570\&poolOnly=true), [EKUBO/STRK 5%](https://app.ekubo.org/positions/new?poolType=twamm\&quoteCurrency=STRK\&baseCurrency=EKUBO\&fee=17014118346046923173168730371588410570\&poolOnly=true), and [EKUBO/USDC 5%](https://app.ekubo.org/positions/new?poolType=twamm\&quoteCurrency=USDC\&baseCurrency=EKUBO\&fee=17014118346046923173168730371588410570\&poolOnly=true).

Approximately `3,269,920` EKUBO was sold for `343.675` ETH, `1,204,770` USDC, and `1,549,920` STRK.

#### Team

The company Ekubo, Inc., a service provider to the DAO, holds one-third of the total supply. There is no vesting schedule for these tokens. The team has come to an agreement with the DAO to hold these tokens indefinitely via [governance proposal](https://app.ekubo.org/governance/proposals/0x1bfc2ccdd2f9a718c45a9aa3a88770435f5272fbfeeb38ca2b3ad54c51c81e9) to fund the company's provision of services.

#### Governance contracts

The governance contract addresses can be found [here](../../integration-guides/reference/contract-addresses.md#governance-contracts).

You can learn more about how the governance contracts work [here](./).

#### Disclaimer

The EKUBO token serves only to decentralize the ownership role of the on-chain instance of the core Ekubo Protocol.

Ekubo, Inc., is not in any way obligated to provide service, maintenance, or development for Ekubo Protocol and related tools or services except as explicitly agreed via governance proposal.

The governance infrastructure is necessary security infrastructure: it protects users of Ekubo Protocol from malicious upgrades by requiring a decentralized and interested majority of stakeholders to come to consensus on the validity and safety of the changes.

