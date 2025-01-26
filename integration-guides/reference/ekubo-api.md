---
description: The API that powers Ekubo's interface
---

# Ekubo API

{% hint style="warning" %}
Our API is in alpha and may undergo breaking changes without notice. [Join the Discord](https://discord.ekubo.org) to ask questions or get support.
{% endhint %}

Our API is found at the following endpoints, for Starknet mainnet and sepolia respectively:

* `https://starknet-mainnet-api.ekubo.org`
* `https://starknet-sepolia-api.ekubo.org`

The endpoints for Ethereum mainnet and sepolia are:

* `https://eth-mainnet-api.ekubo.org`
* `https://eth-sepolia-api.ekubo.org`

#### API Architecture

Our API functionality is based entirely on querying the Postgres schema kept up-to-date by the open source indexer repository ([Starknet](https://github.com/EkuboProtocol/starknet-indexer)). You can replicate almost all of the API functionality by simply running your own instance of the indexer and querying the resulting Postgres database. Some of the functionality is even conveniently contained in materialized views.

There are multiple layers of caching with varying TTL between the database and the client. If you have specific latency requirements or need to make a large number of requests per second, it's best to run your own indexer.

#### Rate limiting

We have a rate limiting web application firewall applied to the API. If you would like to make calls in excess of the limit, please reach out on Discord to get a key.

### Endpoints

Our endpoints are documented via OpenAPI 3.1 at the `/openapi.json` endpoint. For example, for Starknet mainnet: [https://mainnet-api.ekubo.org/openapi.json](https://mainnet-api.ekubo.org/openapi.json)

This means you can use it with any REST API explorer, e.g. the [example swagger explorer](https://petstore3.swagger.io/?url=https://mainnet-api.ekubo.org/openapi.json) or postman.
