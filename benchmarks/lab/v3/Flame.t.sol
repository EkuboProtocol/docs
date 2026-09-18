// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {IUniswapV3Pool, V3GasTest} from "./V3Gas.t.sol";

/// @notice Steady-state single-call capture for flamegraphs: setUp performs the same
///         warm-up as the snapshot test, the test itself makes exactly one 1-pool route
///         through the SwapRouter-shaped minimal router, so the flamegraph total matches
///         "v3 route 1 pool steady-state" (the cheapest path an EOA can send).
contract FlameTest is V3GasTest {
    IUniswapV3Pool[] pools;
    address[] tokensIn;

    function setUp() public override {
        super.setUp();
        (IUniswapV3Pool[] memory p, address[] memory t) = _pools(1);
        pools = p;
        tokensIn = t;
        multihopRouter.multiHop(pools, tokensIn, SWAP_AMOUNT, address(this));
    }

    function test_flame_single() public {
        multihopRouter.multiHop(pools, tokensIn, SWAP_AMOUNT, address(this));
    }
}
