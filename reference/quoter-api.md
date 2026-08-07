---
description: The routing API that powers swaps on Ekubo's websites
---

# Quoter API

{% hint style="warning" %}
Like the [Ekubo API](ekubo-api/README.md), the quoter is operated to support our website and may undergo breaking changes without notice. [Join the Discord](https://discord.ekubo.org) to ask questions or get support.
{% endhint %}

The Quoter API is hosted at:

```
https://prod-api-quoter.ekubo.org
```

It returns **block-pinned split routes** for exact-input and exact-output Ekubo Protocol swaps — the same routes the [interface](https://ekubo.org) executes through the [Yul Router](../integration-guides/swapping.md#evm-the-yul-router). Because quotes simulate actual pool state (including [extension](../concepts/extensions.md) behavior), the quoter is the easiest way for aggregators and integrators to price Ekubo liquidity without implementing the pool math.

The API is self-described by an OpenAPI 3.1 document at [https://prod-api-quoter.ekubo.org/openapi.json](https://prod-api-quoter.ekubo.org/openapi.json), usable with any REST explorer.

### Endpoints

Each operation below is rendered from the OpenAPI specification — expand one
for its full request/response schemas, or use **Test it** to send a request to
the live API directly from this page. (`GET /openapi.json` serves the
specification itself.)

{% openapi src="https://prod-api-quoter.ekubo.org/openapi.json" path="/{chainId}/{amount}/{specifiedToken}/{otherToken}" method="get" %}
[openapi.json](https://prod-api-quoter.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api-quoter.ekubo.org/openapi.json" path="/{chainId}/health" method="get" %}
[openapi.json](https://prod-api-quoter.ekubo.org/openapi.json)
{% endopenapi %}

{% openapi src="https://prod-api-quoter.ekubo.org/openapi.json" path="/" method="get" %}
[openapi.json](https://prod-api-quoter.ekubo.org/openapi.json)
{% endopenapi %}

Notes:

* All token amounts are base-unit decimal strings; a negative `amount` requests an exact-output quote.
* Resolve token addresses and decimals through the [Ekubo API](ekubo-api/README.md) token list before requesting a quote.
* Quotes are pinned to a block, so route calldata should be encoded and submitted promptly (see [Swapping](../integration-guides/swapping.md) for executing the returned route).
