---
description: >-
  The open source service that turns Ekubo's on-chain events into a queryable
  Postgres database — and how to bootstrap one from a nightly dump
---

# Indexer

The [indexer](https://github.com/EkuboProtocol/indexer) is the open-source service that ingests Ekubo events into a Postgres database. It is the same code that powers the public [Ekubo API](../reference/ekubo-api/README.md), so anything the API can answer, your own instance can answer too.

Its design goal is an **always-consistent realtime view**: events are cataloged rather than transformed, and the schema is reorg-safe. Analysis happens on top, in materialized views and queries, so the raw record stays faithful to the chain.

Run your own instance when you need lower latency than the public API, higher request volume than its rate limits allow, or direct SQL access for analytics.

## Bootstrapping from a database dump

Syncing a fresh database across all networks takes **days**. You almost never want to do that. Instead, start from a published dump.

A nightly workflow (`.github/workflows/pg-dump.yaml`) runs `pg_dump -Fc` against the production database and uploads the result as a GitHub Actions artifact:

1. Open the [Actions tab](https://github.com/EkuboProtocol/indexer/actions) of the indexer repository and select the most recent **pg-dump** run.
2. Download the artifact — named `db-backup-<run_id>`, containing `db-backup-<timestamp>.dump`.
3. Restore it into your Postgres instance:

```bash
pg_restore --clean --if-exists --no-owner \
  --dbname postgres://user:pass@host:5432/dbname \
  db-backup-20240101T000000Z.dump
```

{% hint style="info" %}
Artifacts are retained for **7 days**, so grab a recent run. During restore you may see warnings about the DigitalOcean `doadmin` role or the `pg_cron` extension — those are expected and safe to ignore if your target database lacks those privileges or extensions.
{% endhint %}

Once restored, start the indexer and it will catch up from the dump's head to the current chain tip.

## Running it

A prebuilt image is published to the GitHub Container Registry for every commit:

```bash
docker pull ghcr.io/ekuboprotocol/indexer:<git-sha>
```

Bun executes the TypeScript sources directly, so there is no build step. Run the entrypoint for the chain family you want, with `NETWORK` selecting the specific network:

```bash
docker run --rm -e NETWORK=mainnet ekubo-indexer bun src/starknet.ts   # Starknet
docker run --rm -e NETWORK=mainnet ekubo-indexer bun src/evm.ts        # EVM chains
```

Point it at Postgres with `PG_CONNECTION_STRING`, and apply the schema first:

```bash
docker run --rm --env-file .env ekubo-indexer scripts/migrate.ts
```

Migrations live under `migrations/` and run in order. Apply them **before** rolling out new workers.

The repository also includes a DigitalOcean App Platform spec (`.do/app.yaml`) describing the full production stack — a worker per network, managed Postgres, a pre-deploy migration job, and the price-sync process. Use it as a template for reproducing the setup elsewhere.

## What's in the database

Tables mirror Ekubo's on-chain events and derived state: pool initializations and swaps, position updates, per-tick liquidity, pool TVL, TWAMM sale rates and orders, oracle snapshots, Ve33 staking and voting, and ERC-20 token metadata with USD price history. Aggregations such as hourly volume and 24-hour pool statistics are maintained as views.

The repository keeps a **breaking changelog** documenting every schema change and any deployment that needs manual intervention. Read it before upgrading a running instance — some entries change columns that downstream consumers depend on.

{% hint style="info" %}
Token metadata is not written by the indexer. It is owned by the [`default-tokens`](https://github.com/EkuboProtocol/default-tokens) repository, which syncs metadata into the database separately.
{% endhint %}

Need help running one? Ask in the `#devs` channel of the [Discord](https://discord.ekubo.org).
