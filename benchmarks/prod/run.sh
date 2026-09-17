#!/usr/bin/env sh
# Runs the production-contract bench on a fork of the latest mainnet block.
#   RPC=https://eth.drpc.org ./run.sh            # latest block (default)
#   RPC=... BLOCK=25999935 ./run.sh              # reproduce a recorded run
# Dependencies (lib/, git-ignored): forge-std, solady, EkuboProtocol/evm-contracts at
# v3.2.0 (as lib/ekubo, with its lib/forge-std and lib/solady), Uniswap/v4-core (with its
# lib/solmate). Routes: `bun encode-prod-routes.mjs` regenerates calldata/ekubo-yul-*.hex.
set -eu
RPC="${RPC:-https://eth.drpc.org}"
BLOCK="${BLOCK:-$(cast block-number -r "$RPC")}"
echo "fork block $BLOCK"
forge test --fork-url "$RPC" --fork-block-number "$BLOCK" -vv "$@"
