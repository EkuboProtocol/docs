# docs.ekubo.org

The Ekubo documentation. This is a static [Astro Starlight](https://starlight.astro.build/) site deployed to Cloudflare Pages on every push to `main`.

Authored documentation lives in `src/content/docs/`. Static API reference pages are generated at build time from the live Ekubo API and Quoter API OpenAPI 3.1 documents. The `/api-explorer/` routes use the MIT-licensed [Scalar](https://github.com/scalar/scalar) API reference for interactive requests.

## Develop

```sh
bun install
bun run dev
bun run check
bun run build
bun run preview
```

`bun run build` downloads and validates both live OpenAPI documents before generating the site. The exact inputs are published at `/openapi/ekubo.json` and `/openapi/quoter.json`.

## Content

Every page requires `title` and `description` front matter. The path under `src/content/docs/` becomes its public URL; `index.md` represents its directory root.

The sidebar is intentionally explicit in `astro.config.mjs`. Add each authored page there exactly once. API routes are inserted automatically from their OpenAPI tags.

## Agent access

The build emits:

- `/llms.txt` as the discovery index;
- `/llms-small.txt` as an abridged corpus;
- `/llms-full.txt` as the complete authored documentation;
- both OpenAPI documents as machine-readable JSON;
- static HTML for every OpenAPI operation.

## Deployment

Cloudflare Pages project `ekubo-docs` builds the private `EkuboProtocol/docs` repository.

| Setting           | Value                                            |
| ----------------- | ------------------------------------------------ |
| Build command     | `bun install --frozen-lockfile && bun run build` |
| Output directory  | `dist`                                           |
| Production branch | `main`                                           |
| `BUN_VERSION`     | `1.3.14`                                         |
