---
description: >-
  All the endpoints available in the Ekubo API, generated from the OpenAPI 3.1
  specification
---

# Endpoints



{% openapi-operation spec="ekubo-api" path="/tokens" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/tokens/batch" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/tokens/{chainId}/{tokenAddress}" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/blocks/{chainId}/closest" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/blocks/{chainId}/{blockTag}" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/overview/pairs" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/overview/boosted-fees-pools" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/overview/revenue" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/overview/tvl" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/overview/volume" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/pair/{chainId}/{tokenA}/{tokenB}/tvl" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/pair/{chainId}/{tokenA}/{tokenB}/volume" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/pair/{chainId}/{tokenA}/{tokenB}/pools" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/price/{chainId}/{baseToken}/{quoteToken}/history" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/pools/{chainId}/{coreAddress}/{poolId}/price/history" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/pools/{chainId}/{coreAddress}/{poolId}/key" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/pools/{chainId}/{coreAddress}/{poolId}/liquidity" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/tokens/{chainId}/{tokenA}/{tokenB}/liquidity" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/pair/{chainId}/{tokenA}/{tokenB}/positions" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/tokens/{chainId}/{tokenA}/{tokenB}/events" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/positions/{address}" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/positions/{chainId}/{lockerAddress}/{id}/history" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/positions/{chainId}/{nftAddress}/{id}" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/orders/{chainId}/{nftAddress}/{id}/image.svg" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/orders/{chainId}/{nftAddress}/{id}" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/twap/pools/{chainId}/{coreAddress}/{tokenA}/{tokenB}/{fee}" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/twap/pair/{chainId}/{tokenA}/{tokenB}" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/twap/orders/{address}" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/limit-orders/orders/{address}" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/positions/{chainId}/{nftAddress}/{id}/image.svg" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/nft/{chainId}/{nftAddress}/{id}" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/nft/{chainId}/{nftAddress}/{id}/image.svg" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/auctions" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/auctions/{chainId}/{nftAddress}/{id}" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/auctions/{chainId}/{nftAddress}/{id}/image.svg" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/auctions/{chainId}/{nftAddress}/{id}/state" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/governance/{chainId}/proposals" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/governance/{chainId}/delegates" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/governance/{chainId}/proposals/{proposalId}/votes" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/governance/{chainId}/proposals/{proposalId}/voters" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/governance/{chainId}/delegates/{address}" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/campaigns" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/rewards/{chainId}/{locker}/{salt}" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}

{% openapi-operation spec="ekubo-api" path="/claims/{address}" method="get" %}
[OpenAPI ekubo-api](https://prod-api.ekubo.org/openapi.json)
{% endopenapi-operation %}
