---
description: >-
  All the endpoints available in the Ekubo API, generated from the OpenAPI 3.1
  specification
---

# Endpoints

The canonical, always-current reference is the OpenAPI 3.1 document served by
the API itself: [https://prod-api.ekubo.org/openapi.json](https://prod-api.ekubo.org/openapi.json),
which can also be imported into REST clients like Postman.

All endpoints take a `chainId` (path or query parameter) identifying the
network — the API serves every chain Ekubo is deployed to and indexes.

Each operation below is rendered from the OpenAPI specification — expand one
for its full request/response schemas, or use **Test it** to send a request to
the live API directly from this page.

### Tokens

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/tokens" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/tokens/batch" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/tokens/{chainId}/{tokenAddress}" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/tokens/{chainId}/{tokenAddress}/price-history" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/tokens/{chainId}/{tokenA}/{tokenB}/events" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/tokens/{chainId}/{tokenA}/{tokenB}/liquidity" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

### Prices

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/price/{chainId}/{baseToken}/{quoteToken}/history" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

### Pools

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/pools/{chainId}/{coreAddress}/{poolId}/key" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/pools/{chainId}/{coreAddress}/{poolId}/liquidity" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/pools/{chainId}/{coreAddress}/{poolId}/positions" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/pools/{chainId}/{coreAddress}/{poolId}/price/history" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

### Pairs

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/pair/{chainId}/{tokenA}/{tokenB}/pools" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/pair/{chainId}/{tokenA}/{tokenB}/positions" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/pair/{chainId}/{tokenA}/{tokenB}/tvl" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/pair/{chainId}/{tokenA}/{tokenB}/volume" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

### Positions

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/positions/batch" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/positions/{address}" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/positions/{chainId}/events" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/positions/{chainId}/{lockerAddress}/{id}/history" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/positions/{chainId}/{nftAddress}/{id}" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/positions/{chainId}/{nftAddress}/{id}/image.svg" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

### Protocol overview

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/overview/boosted-fees-pools" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/overview/pairs" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/overview/revenue" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/overview/tvl" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/overview/volume" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

### Blocks

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/blocks/{chainId}/closest" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/blocks/{chainId}/{blockTag}" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

### DCA orders

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/orders/{chainId}/{nftAddress}/{id}" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/orders/{chainId}/{nftAddress}/{id}/image.svg" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

### Limit orders

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/limit-orders/orders/{address}" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

### Auctions

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/auctions" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/auctions/{chainId}/{nftAddress}/{id}" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/auctions/{chainId}/{nftAddress}/{id}/image.svg" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/auctions/{chainId}/{nftAddress}/{id}/state" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

### NFT metadata

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/nft/{chainId}/{nftAddress}/{id}" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/nft/{chainId}/{nftAddress}/{id}/image.svg" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

### Governance

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/governance/{chainId}/delegates" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/governance/{chainId}/delegates/{address}" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/governance/{chainId}/proposals" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/governance/{chainId}/proposals/{proposalId}/voters" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/governance/{chainId}/proposals/{proposalId}/votes" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

### Campaigns & rewards

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/campaigns" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/claims/{address}" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/rewards/{chainId}/{locker}/{salt}" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

### Misc

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/country" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/twap/orders/batch" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/twap/orders/{address}" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/twap/pair/{chainId}/{tokenA}/{tokenB}" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/twap/pools/{chainId}/{coreAddress}/{poolId}" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/twap/pools/{chainId}/{coreAddress}/{tokenA}/{tokenB}/{fee}" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/ve33/{ve33Address}/pools" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api.ekubo.org/openapi.json" path="/ve33/{veTokenAddress}/{address}" method="get" %}
[openapi.json](https://prod-api.ekubo.org/openapi.json)
{% endopenapi %}

