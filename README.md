# docs.ekubo.org

The Ekubo documentation. This is a static [Astro Starlight](https://starlight.astro.build/) site deployed to Cloudflare Pages on every push to `main`.

Authored documentation lives in `src/content/docs/`. The unified `/api/` reference uses the MIT-licensed [Scalar](https://github.com/scalar/scalar) interface to search, inspect, and test both the Ekubo API and Quoter API from live OpenAPI 3.1 documents.

## Develop

```sh
bun install
bun run dev
bun run check
bun run build
bun run preview
```

`bun run build` downloads and validates both live OpenAPI documents before generating the site. The exact inputs are published at `/openapi/ekubo.json` and `/openapi/quoter.json`.

The build also regenerates `public/_redirects` from `scripts/legacy-routes.mjs`. `bun run check:legacy` verifies that every page from the previous GitBook site still has a built route and that its file-path and moved-page URL variants redirect to the canonical location.

## Content

Every page requires `title` and `description` front matter. The path under `src/content/docs/` becomes its public URL; `index.md` represents its directory root.

The sidebar is intentionally explicit in `astro.config.mjs`. Add each authored page there exactly once. The API reference is a single custom route at `src/pages/api/index.astro`.

## Agent access

The build emits:

- `/llms.txt` as the discovery index;
- `/llms-small.txt` as an abridged corpus;
- `/llms-full.txt` as the complete authored documentation;
- both OpenAPI documents as machine-readable JSON;
- a unified interactive reference for both APIs.

## Deployment

Cloudflare Pages project `ekubo-docs` builds the private `EkuboProtocol/docs` repository.

| Setting           | Value                                            |
| ----------------- | ------------------------------------------------ |
| Build command     | `bun install --frozen-lockfile && bun run build` |
| Output directory  | `dist`                                           |
| Production branch | `main`                                           |
| `BUN_VERSION`     | `1.3.14`                                         |
