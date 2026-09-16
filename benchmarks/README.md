# Gas benchmark harnesses

Foundry tests behind the numbers on the [Gas efficiency](/concepts/gas-efficiency/) page.
Each protocol compiles under its own production toolchain settings, so the comparison
measures code and architecture rather than compiler tuning.

## Layout

- `lab/ekubo/` — Ekubo EVM swaps and mints (`EkuboGas.t.sol`, plus `Flame.t.sol`
  for single-call flamegraph captures)
- `lab/v4/` — Uniswap v4 swaps and mints (`V4Gas.t.sol`, `Flame.t.sol`)
- `lab/v3/` — Uniswap v3 swaps and mints (`V3Gas.t.sol`, `Flame.t.sol`)
- `lab/MockERC20.json` — the single shared token artifact deployed via `deployCode`
  in all three lab harnesses, so ERC20 transfer costs cannot skew the comparison
- `fork/` — mainnet-fork validation at pinned block `25991868`
  (`ForkEkuboReal.t.sol`, `ForkV3.t.sol`, `ForkV4.t.sol`, plus the pool probe)

`remappings.txt` files contain the original absolute paths and will need adjusting;
the dependency pins below are what matter for reproduction.

## Lab methodology (all three harnesses)

Each test runs on a fresh chain (`isolate`). Pools are capitalized in setup;
single-hop figures are cold-path measurements with no warm-up swap, the closest
a harness gets to a real user's transaction (which always starts cold).
Multihop scaling figures are warmed (one identical unmeasured route first),
matching in-route conditions where later hops execute warm. `vm.cool` was
verified to be a no-op in this setup and is not used.

- Concentrated pools, 0.3% fee, range covering the whole tick space, so no swap
  crosses an initialized tick.
- Pools initialized strictly inside a tick (Ekubo tick 3050, Uniswap tick 30),
  never on a tick-spacing multiple.
- Economically matched liquidity: 1M tokens a side on Ekubo and v4; v3 mints
  the equivalent liquidity (998501199320305883812938) computed for the same
  amounts.
- 1-token exact-input swaps, both directions; multihop routers deliver output
  to the calling user (an earlier v4 router that retained output was fixed;
  the numbers did not move).
- Gas read with `vm.snapshotGasLastCall` immediately after the measured call;
  `*.json` files are the raw snapshots. `Flame.t.sol` files capture one
  cold-path call each for the flamegraphs.

Scaling series (1/2/3 hops) use the same minimal single-lock router per protocol,
so the per-hop marginal is apples-to-apples. Mint tests are subsequent mints
with boundary ticks already initialized.

## Fork methodology

Same pair (USDT to USDC), same size (1000 USDT), warmed with one identical
unmeasured swap, negligible tick movement (0–1 ticks), pinned block `25991868`:

- Ekubo: the live USDC/USDT concentrated pool (spacing 50, core-only) through
  the deployed production Yul router, with SDK-generated calldata
  (see `fork/encode-yul-route.mjs`).
- v3: the deepest fee-100 pool through the deployed SwapRouter.
- v4: the deepest fee-100 pool through the deployed PoolManager with a minimal
  locker (the Universal Router would cost more).

USDT returns no returndata, so approvals and v4 settlement use low-level calls,
mirroring production routers.

## Dependency pins

- Ekubo `evm-contracts` worktree at commit `1f5be49` (plus the harness test files
  in this directory); `forge-std` `77041d2`, `solady` `65e87c7`; solc `0.8.33`,
  `optimizer_runs = 9999999`, `via_ir`, `evm_version = "osaka"`.
- Uniswap `v4-core` commit `46c6834`; solc `0.8.26`,
  `optimizer_runs = 44444444`, `via_ir`, `evm_version = "cancun"`
  (v4-core's own `foundry.toml`).
- Uniswap `v3-core` `1.0.1` canonical mainnet bytecode
  (`@uniswap/v3-core` npm artifacts, `UniswapV3Factory.json`).
- Shared token: solmate `MockERC20` bytecode in `lab/MockERC20.json`.
- Yul router SDK (`ekubo/yul-router`) for the fork calldata generation.
- Foundry `1.8.3`.

## Reproducing the lab numbers

```sh
# v4 (from a checkout of Uniswap/v4-core@46c6834 with submodules initialized)
forge test --match-contract V4GasTest
forge snapshot --match-contract V4GasTest

# ekubo (remap ekubo/, forge-std/, solady/ at the pins above, deployCode the token)
forge test --offline --match-contract EkuboGasTest
forge snapshot --offline --match-contract EkuboGasTest

# v3 (needs UniswapV3Factory.json next to MockERC20.json under artifacts/)
forge test --match-contract V3GasTest
forge snapshot --match-contract V3GasTest
```

## Reproducing the fork numbers

```sh
forge test --fork-url <mainnet-rpc> --fork-block-number 25991868 \
  --match-contract 'ForkEkuboRealTest|ForkV3Test|ForkV4Test'
```

Deployed addresses used (all verified on-chain, none memorized):

| Contract                        | Address                                      |
| ------------------------------- | -------------------------------------------- |
| Ekubo Core                      | `0x00000000000014aA86C5d3c41765bb24e11bd701` |
| Ekubo Yul router (production)   | `0x7B2aA7Ecc0B5936b7C52E6259A19C3BA557d0748` |
| Uniswap v4 PoolManager          | `0x000000000004444c5dc75cB358380D2e3dE08A90` |
| Uniswap v3 SwapRouter (classic) | `0xE592427A0AEce92De3Edee1F18E0157C05861564` |
| Uniswap v3 factory              | `0x1F98431c8aD98523631AE4a59f267346ea31F984` |
| WETH                            | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` |
| USDC                            | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| USDT                            | `0xdAC17F958D2ee523a2206206994597C13D831ec7` |

The v3/v4 fork pools (USDT/USDC fee-100, deepest at the pinned block) were
selected by on-chain probing (see `ForkProbe.t.sol`); the Ekubo pool came from
the production quoter.
