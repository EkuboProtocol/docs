// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {V4GasTest} from "./V4Gas.t.sol";

/// @notice Steady-state single-call capture for flamegraphs: setUp performs the same
///         warm-up swap as the snapshot test, the test itself makes exactly one swap, so
///         the flamegraph total matches "v4 single erc20 steady-state".
contract FlameTest is V4GasTest {
    function setUp() public override {
        super.setUp();
        _swapAB();
    }

    function test_flame_single() public {
        assertGt(_swapAB(), 0);
    }
}
