---
description: >-
  All the endpoints available in the Ekubo API, generated from the OpenAPI 3.1
  specification
---

# Endpoints

The canonical, always-current reference is the OpenAPI 3.1 document served by
the API itself: [https://prod-api.ekubo.org/openapi.json](https://prod-api.ekubo.org/openapi.json).
You can load it into any REST explorer (e.g. [Swagger UI](https://petstore3.swagger.io/?url=https://prod-api.ekubo.org/openapi.json)
or Postman) for full request/response schemas.

All endpoints take a `chainId` (path or query parameter) identifying the
network — the API serves every chain Ekubo is deployed to and indexes.

The summary below is generated from the OpenAPI specification.

### Tokens

| Endpoint | Description |
| --- | --- |
| `GET /tokens` | List tokens |
| `GET /tokens/batch` | Batch tokens |
| `GET /tokens/{chainId}/{tokenAddress}` | Get token |
| `GET /tokens/{chainId}/{tokenAddress}/price-history` | Get token USD price history |
| `GET /tokens/{chainId}/{tokenA}/{tokenB}/events` | Get pair events |
| `GET /tokens/{chainId}/{tokenA}/{tokenB}/liquidity` | Get pair liquidity |

### Prices

| Endpoint | Description |
| --- | --- |
| `GET /price/{chainId}/{baseToken}/{quoteToken}/history` | Get price history |

### Pools

| Endpoint | Description |
| --- | --- |
| `GET /pools/{chainId}/{coreAddress}/{poolId}/key` | Get pool key |
| `GET /pools/{chainId}/{coreAddress}/{poolId}/liquidity` | Get pool liquidity |
| `GET /pools/{chainId}/{coreAddress}/{poolId}/positions` | Get top positions for pool |
| `GET /pools/{chainId}/{coreAddress}/{poolId}/price/history` | Get pool price history |

### Pairs

| Endpoint | Description |
| --- | --- |
| `GET /pair/{chainId}/{tokenA}/{tokenB}/pools` | Get pools of pair |
| `GET /pair/{chainId}/{tokenA}/{tokenB}/positions` | Get top positions for pair |
| `GET /pair/{chainId}/{tokenA}/{tokenB}/tvl` | Get pair TVL |
| `GET /pair/{chainId}/{tokenA}/{tokenB}/volume` | Get pair volume |

### Positions

| Endpoint | Description |
| --- | --- |
| `GET /positions/batch` | Batch list positions |
| `GET /positions/{address}` | List positions |
| `GET /positions/{chainId}/events` | List position events |
| `GET /positions/{chainId}/{lockerAddress}/{id}/history` | List position history |
| `GET /positions/{chainId}/{nftAddress}/{id}` | Get NFT Metadata |
| `GET /positions/{chainId}/{nftAddress}/{id}/image.svg` | Get NFT Image |

### Protocol overview

| Endpoint | Description |
| --- | --- |
| `GET /overview/boosted-fees-pools` | Get boosted fees pools |
| `GET /overview/pairs` | Get pairs |
| `GET /overview/revenue` | Get revenue |
| `GET /overview/tvl` | Get TVL |
| `GET /overview/volume` | Get volume |

### Blocks

| Endpoint | Description |
| --- | --- |
| `GET /blocks/{chainId}/closest` | Get the block closest to a given timestamp |
| `GET /blocks/{chainId}/{blockTag}` | Get block |

### DCA orders

| Endpoint | Description |
| --- | --- |
| `GET /orders/{chainId}/{nftAddress}/{id}` | Get NFT Metadata |
| `GET /orders/{chainId}/{nftAddress}/{id}/image.svg` | Get NFT Image |

### Limit orders

| Endpoint | Description |
| --- | --- |
| `GET /limit-orders/orders/{address}` | List limit orders |

### Auctions

| Endpoint | Description |
| --- | --- |
| `GET /auctions` | List auction keys |
| `GET /auctions/{chainId}/{nftAddress}/{id}` | Get auction NFT metadata |
| `GET /auctions/{chainId}/{nftAddress}/{id}/image.svg` | Get auction NFT image |
| `GET /auctions/{chainId}/{nftAddress}/{id}/state` | Get auction NFT state |

### NFT metadata

| Endpoint | Description |
| --- | --- |
| `GET /nft/{chainId}/{nftAddress}/{id}` | Get NFT Metadata |
| `GET /nft/{chainId}/{nftAddress}/{id}/image.svg` | Get NFT Image |

### Governance

| Endpoint | Description |
| --- | --- |
| `GET /governance/{chainId}/delegates` | List Top Delegates |
| `GET /governance/{chainId}/delegates/{address}` | Get Staker Info |
| `GET /governance/{chainId}/proposals` | List Proposals |
| `GET /governance/{chainId}/proposals/{proposalId}/voters` | List Voters |
| `GET /governance/{chainId}/proposals/{proposalId}/votes` | List Votes |

### Campaigns & rewards

| Endpoint | Description |
| --- | --- |
| `GET /campaigns` | List campaigns |
| `GET /claims/{address}` | List available claims |
| `GET /rewards/{chainId}/{locker}/{salt}` | Get position rewards |

### Misc

| Endpoint | Description |
| --- | --- |
| `GET /country` | Get request country |
| `GET /twap/orders/batch` | Batch list TWAP orders |
| `GET /twap/orders/{address}` | List TWAP orders |
| `GET /twap/pair/{chainId}/{tokenA}/{tokenB}` | Get TWAP pair |
| `GET /twap/pools/{chainId}/{coreAddress}/{poolId}` | Get TWAP pool by pool id |
| `GET /twap/pools/{chainId}/{coreAddress}/{tokenA}/{tokenB}/{fee}` | Get TWAP pool |
| `GET /ve33/{ve33Address}/pools` | List ve33 pools |
| `GET /ve33/{veTokenAddress}/{address}` | List ve33 tokens |

