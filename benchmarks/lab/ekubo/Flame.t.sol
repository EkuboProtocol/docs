// SPDX-License-Identifier: ekubo-license-v1.eth
pragma solidity =0.8.33;

import {EkuboGasTest} from "./EkuboGas.t.sol";

/// @notice Steady-state single-call capture for flamegraphs: setUp performs the same
///         warm-up swap as the snapshot test, the test itself makes exactly one swap, so
///         the flamegraph total matches "ekubo single erc20 steady-state".
contract FlameTest is EkuboGasTest {
    function setUp() public override {
        super.setUp();
        _swapAB();
    }

    function test_flame_single() public {
        _swapAB();
    }
}
