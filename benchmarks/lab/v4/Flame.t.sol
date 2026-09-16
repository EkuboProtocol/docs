// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {Currency} from "v4-core/src/types/Currency.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {V4GasTest} from "./V4Gas.t.sol";

/// @notice Warmed single-call capture for flamegraphs: setUp warms the pool,
///         the test itself makes exactly one swap, so flamegraph totals match
///         the warmed snapshot numbers.
contract FlameTest is V4GasTest {
    function setUp() public override {
        super.setUp();
        minRouter.swapExactIn(keyAB, true, SWAP_AMOUNT, TickMath.MIN_SQRT_PRICE + 1, address(this));
    }

    function test_flame_single() public {
        uint256 out = minRouter.swapExactIn(keyAB, true, SWAP_AMOUNT, TickMath.MIN_SQRT_PRICE + 1, address(this));
        assertGt(out, 0);
    }
}
