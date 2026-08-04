---
description: What you can do with Ekubo, and the infrastructure behind it
---

# Products

Ekubo is more than an AMM contract. It is a set of products built around one shared liquidity layer — for traders, liquidity providers, ecosystems bootstrapping their own markets, and developers who need the underlying data.

### [Trading](trading.md)

Swap across every Ekubo pool with routing that accounts for extension behavior. Quotes come from a public routing service that returns block-pinned split routes, which execute through a gas-optimized router in a single transaction.

### [Providing liquidity](liquidity.md)

Supply concentrated, stableswap, or full-range liquidity in the same Core contract. Extensions add behavior on top — automatic order execution, MEV capture, externally funded fee boosts — without fragmenting liquidity into separate protocols.

### [Ve33 and STONX](ve33.md)

A token-governed liquidity marketplace anyone can deploy around their own token. Holders lock the stake token, direct emissions to pools, set those pools' fees, and earn the fees of the pools they support. **STONX** on Robinhood Chain is the first ecosystem deployment, coordinating liquidity across stock-token markets.

### [Rewards and incentives](rewards.md)

Liquidity incentive campaigns that measure real, useful liquidity and distribute rewards through periodic on-chain drops. Claims are merkle-based and permissionless, and anyone can fund a drop.

### [Indexer](indexer.md)

The open source indexer that turns Ekubo's on-chain events into a queryable Postgres database — the same code behind the public API. Nightly database dumps let you bootstrap a node in minutes instead of days.

### [MCP server](mcp-server.md)

A public Model Context Protocol server at `mcp.ekubo.org` that lets AI agents quote swaps, read pools and positions, and build unsigned transactions — non-custodially, with signing left to the user's wallet.

### [Governance](governance.md)

The EKUBO token, the Staker and Governor contracts that control the protocol's upgradeable deployments, how protocol revenue flows back to the DAO, and Ekubo, Inc.'s defined role within it.
