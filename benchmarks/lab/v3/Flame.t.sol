// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {V3GasTest} from "./V3Gas.t.sol";

/// @notice Warmed single-call capture for flamegraphs: setUp warms the pool,
///         the test itself makes exactly one swap, so flamegraph totals match
///         the warmed snapshot numbers.
contract FlameTest is V3GasTest {
    function setUp() public override {
        super.setUp();
        poolAB.swap(address(this), true, SWAP_AMOUNT, MIN_LIMIT, "");
    }

    function test_flame_single() public {
        poolAB.swap(address(this), true, SWAP_AMOUNT, MIN_LIMIT, "");
    }
}
