---
description: The routing API that powers swaps on Ekubo's websites
title: "Quoter API"
---

:::caution
Like the [Ekubo API](/reference/ekubo-api/), the quoter is operated to support our website and may undergo breaking changes without notice. [Join the Discord](https://discord.ekubo.org) to ask questions or get support.
:::

The Quoter API is hosted at:

```
https://prod-api-quoter.ekubo.org
```

It returns **block-pinned split routes** for exact-input and exact-output Ekubo Protocol swaps — the same routes the [interface](https://ekubo.org) executes through the [Yul Router](/integration-guides/swapping/#swapping-on-evm-chains). Because quotes simulate actual pool state (including [extension](/concepts/extensions/) behavior), the quoter is the easiest way for aggregators and integrators to price Ekubo liquidity without implementing the pool math.

The API is self-described by an OpenAPI 3.1 document at [https://prod-api-quoter.ekubo.org/openapi.json](https://prod-api-quoter.ekubo.org/openapi.json), usable with any REST explorer.

### Endpoints

The endpoint reference is generated during every documentation build from the live specification.

- [Browse the static endpoint reference](/api/quoter/)
- [Test requests in the interactive API Explorer](/api-explorer/quoter/)
- [Download the build's OpenAPI snapshot](/openapi/quoter.json)
- [View the canonical live specification](https://prod-api-quoter.ekubo.org/openapi.json)

Notes:

- All token amounts are base-unit decimal strings; a negative `amount` requests an exact-output quote.
- Resolve token addresses and decimals through the [Ekubo API](/reference/ekubo-api/) token list before requesting a quote.
- Quotes are pinned to a block, so route calldata should be encoded and submitted promptly (see [Swapping](/integration-guides/swapping/) for executing the returned route).
