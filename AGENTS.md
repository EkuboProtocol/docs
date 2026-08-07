# Repository Guidelines

GitBook source for [docs.ekubo.org](https://docs.ekubo.org). Pages are Markdown with YAML front matter; `SUMMARY.md` defines the navigation and `.gitbook.yaml` holds redirects. This repository is **public**.

## The cardinal rule: verify against code, not prose

Every factual claim must be checked against the contracts, the SDK sources, or a live on-chain read — **not** against another written document. Nearly every error found in this repository came from trusting a write-up that had drifted from the code:

| Stale source | What it caused |
| --- | --- |
| A proposal pinned to an old release candidate | Documented `Ve33EmissionRateScheduler`, a contract deleted months earlier |
| A repository README | A `docker run` migration command that cannot execute |
| A contract's own markdown doc | Said a swap fee goes to the extension owner; the code credits the extension itself |
| A contract's natspec comment | Described MEV capture as priority-fee based; the implementation uses price movement |
| The original 2024 GitBook | Governance parameters five config versions out of date |

When the code and a document disagree, **the code wins** — and the document should be reported upstream.

Read the code in `~/IdeaProjects/ekubo`: `evm-contracts`, `starknet-contracts`, `governance`, `yul-router`, `indexer`, `rust-sdk`.

### Read live values rather than repeating them

Anything configurable on-chain must be read, not copied from a prior version of the page:

```sh
# Starknet governance parameters
starkli call <governor> get_config --rpc <rpc>

# EVM immutables (e.g. protocol fee)
cast call <positions> "SWAP_PROTOCOL_FEE_X64()(uint64)" --rpc-url <rpc>
```

Cite such values as *current*, note that they are configurable, and point readers at the getter.

## Do not generalize across chains or contracts

Two failure modes worth naming, because both produced confidently wrong pages:

- **Chain scope.** EVM and Starknet differ in ways that invalidate blanket statements — Core is ownerless on EVM but owner-upgradeable on Starknet; call points are immutable on EVM but re-settable on Starknet; several extensions exist on only one chain. Say which chain a claim applies to, or verify it on both.
- **Contract scope.** A property of one contract is not a property of its siblings. "Position metadata renders on-chain" was true of `VeToken` and false of `Positions`. Verify the specific contract you are describing.

## Claims about returns

Do not assert that Ekubo structurally increases yield. Capital efficiency is a **concentration ratio**, not a higher expected return: a narrower range earns more fees per dollar *while in range* and equally amplifies divergence loss and out-of-range frequency. State both sides, or state neither.

Avoid unsupported superlatives ("best execution", "most capital-efficient"). Prefer a checkable statement about a mechanism.

## Private repositories

These are **not public** — never link to them or describe their internals: `api`, `quoter-service`, `typescript-sdk`, `interface`, `incentives`, and the wallet and MCP server repos. You may use them to *verify* a fact; document only the public surface:

| Instead of | Reference |
| --- | --- |
| the `api` repo | `https://prod-api.ekubo.org` and its OpenAPI document |
| the `quoter-service` repo | `https://prod-api-quoter.ekubo.org` and its OpenAPI document |
| the `typescript-sdk` repo | the `@ekubo/sdk` npm package |
| the `interface` repo | `https://ekubo.org` |

Before pushing, confirm every referenced repository is public:

```sh
grep -rhoE "github\.com/EkuboProtocol/[a-zA-Z0-9_-]+" --include="*.md" . | sort -u \
  | while read u; do r=${u##*/}; gh api repos/EkuboProtocol/$r \
      --jq "if .private then \"PRIVATE: $r\" else empty end"; done
```

## Structure

Sections, in navigation order, each with a distinct job:

- **About Ekubo** — what the protocol is; accessible, no implementation detail
- **Products** — what you can do with it, one page per facet
- **Concepts** — how the protocol works, chain-agnostic where possible
- **User Guides** — task-oriented instructions for the app
- **Integration Guides** — task-oriented instructions for developers
- **Reference** — lookup material: addresses, APIs, math, audits

Put a page where a reader would look for it, not where it was first written. Reference material belongs in Reference even if it started as a concept.

Do not restate math that has canonical published references. Link the reference and document only what is Ekubo-specific — see `reference/pool-math.md`.

## Style

- Front matter carries a one-sentence `description` on every page
- Emoji live in `SUMMARY.md` only; page `# H1`s are plain
- Prefer prose over bullet fragments for explanation; use tables for enumerable facts
- Write for a reader who has not read the other pages

## Before you commit

- Every moved or renamed page gets a redirect in `.gitbook.yaml`
- `SUMMARY.md` lists every page, and every page is listed exactly once
- All relative links and `.gitbook/assets/` references resolve — note that moving a page changes its directory depth and silently breaks `../` paths
- No em dashes or entities introduced inside fenced code blocks; shell flags such as `--rm` intact
