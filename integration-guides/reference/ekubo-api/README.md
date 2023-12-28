---
description: Introduction to the public API we run for our interface
---

# Ekubo API

{% hint style="warning" %}
Our API is in early alpha and may undergo breaking changes without notice. [Join the Discord](https://discord.ekubo.org) to ask questions or get support.
{% endhint %}

Our API is found at two endpoints:

* https://mainnet-api.ekubo.org
* https://goerli-api.ekubo.org

These endpoints serve the Starknet Mainnet and Goerli deployments of Ekubo, respectively.

#### Architecture

Our API functionality is based entirely on the indexer repository. You can replicate most of the API functionality by simply running your own instance of the [indexer](https://github.com/ekuboprotocol/indexer) and querying the resulting Postgres database.

#### Rate limiting

We have a rate limiting web application firewall applied to the API. If you would like to make calls in excess of the limit, please reach out on Discord to discuss an arrangement.
