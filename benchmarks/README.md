# Gas benchmark harnesses

Foundry tests behind the numbers on the [Gas efficiency](/concepts/gas-efficiency/) page.
Each protocol compiles under its own production toolchain settings, so the comparison
measures code and architecture rather than compiler tuning.

## Layout

- `lab/ekubo/` — Ekubo EVM swaps and mints (`EkuboGas.t.sol`)
- `lab/v4/` — Uniswap v4 swaps and mints (`V4Gas.t.sol`)
- `lab/v3/` — Uniswap v3 swaps and mints (`V3Gas.t.sol`)
- `lab/MockERC20.json` — the single shared token artifact deployed via `deployCode`
  in all three lab harnesses, so ERC20 transfer costs cannot skew the comparison
- `fork/` — mainnet-fork validation at pinned block `25991868`
  (`ForkEkubo.t.sol`, `ForkV3.t.sol`, `ForkV4.t.sol`, plus the pool probe)

`remappings.txt` files contain the original absolute paths and will need adjusting;
the dependency pins below are what matter for reproduction.

## Lab methodology (all three harnesses)

- Full-range-equivalent positions (concentrated pools, range covering the whole
  tick space) at a 0.3% fee, so no swap crosses an initialized tick.
- Pools initialized strictly inside a tick (Ekubo tick 3050, Uniswap tick 30),
  never on a tick-spacing multiple.
- 1,000,000-token liquidity per side, 1-token exact-input swaps, both directions.
- `forge-config: default.isolate = true` plus `vm.cool(...)` on every contract,
  so each measurement is a cold-access transaction.
- Gas read with `vm.snapshotGasLastCall`; `*.json` files are the raw snapshots.

Scaling series (1/2/3 hops) use the same minimal single-lock router per protocol,
so the per-hop marginal is apples-to-apples.

## Dependency pins

- Ekubo `evm-contracts`: branch `gas-benchmarks` worktree at commit `1f5be49`
  (plus the harness test file in this directory); `forge-std` `77041d2`,
  `solady` `65e87c7`; solc `0.8.33`, `optimizer_runs = 9999999`, `via_ir`,
  `evm_version = "osaka"`.
- Uniswap `v4-core` commit `46c6834`; solc `0.8.26`,
  `optimizer_runs = 44444444`, `via_ir`, `evm_version = "cancun"`
  (v4-core's own `foundry.toml`).
- Uniswap `v3-core` `1.0.1` canonical mainnet bytecode
  (`@uniswap/v3-core` npm artifacts, `UniswapV3Factory.json`).
- Shared token: solmate `MockERC20` bytecode in `lab/MockERC20.json`.
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
  --match-contract 'ForkV3Test|ForkV4Test|ForkEkuboTest'
```

Deployed addresses used (all verified on-chain, none memorized):

| Contract                        | Address                                      |
| ------------------------------- | -------------------------------------------- |
| Ekubo Core                      | `0x00000000000014aA86C5d3c41765bb24e11bd701` |
| Uniswap v4 PoolManager          | `0x000000000004444c5dc75cB358380D2e3dE08A90` |
| Uniswap v3 SwapRouter (classic) | `0xE592427A0AEce92De3Edee1F18E0157C05861564` |
| Uniswap v3 factory              | `0x1F98431c8aD98523631AE4a59f267346ea31F984` |
| WETH                            | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` |
| USDC                            | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |

The v4 fork pool (WETH/USDC, fee 500) was selected by probing candidate fee
tiers for the deepest pool at the pinned block (see `ForkProbe.t.sol`).
