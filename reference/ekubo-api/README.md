---
description: The API that powers Ekubo's websites
---

# Ekubo API

{% hint style="warning" %}
Our API is available to support our website and may undergo breaking changes without notice. [Join the Discord](https://discord.ekubo.org) to ask questions or get support.
{% endhint %}

The API URL is hosted at the following URL:

`https://prod-api.ekubo.org`

It contains data for all the chains that we are deployed to and index. It also hosts an [OpenAPI 3.1 document](https://prod-api.ekubo.org/openapi.json) that self-describes all the endpoints.

### API Architecture

Our API functionality is based entirely on querying the Postgres schema kept up-to-date by the open-source indexer repository ([GitHub](https://github.com/EkuboProtocol/indexer)). You can replicate all of the API functionality by simply running your own instance of the Indexer and querying the your own Postgres database. Much of the API functionality is conveniently contained in views and scheduled jobs allowing you to easily replicate all the functionalities of our API.

#### Caching

There are multiple layers of caching with varying TTL between the database and the client. If you have specific latency requirements or need to make a large number of requests per second, it's best to run your own indexer.

#### Rate limiting

We have a rate limiting web application firewall (WAF) in front of the API. If you would like to make calls in excess of the limit, please reach out on [Discord](https://discord.ekubo.org/) to find a solution. The rate limit is not fixed and we can change it as necessary to control costs or ensure fair access to all users. Generally we will not create exceptions for you to exceed our public API rate limits.

### Endpoints

Our endpoints are documented via OpenAPI 3.1 at the `/openapi.json` endpoint. The URL is [https://prod-api.ekubo.org/openapi.json](https://prod-api.ekubo.org/openapi.json)

This means you can use it with any REST API explorer, e.g. the [example swagger explorer](https://petstore3.swagger.io/?url=https://prod-api.ekubo.org/openapi.json) or postman.
