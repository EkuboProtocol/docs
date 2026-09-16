// SPDX-License-Identifier: ekubo-license-v1.eth
pragma solidity =0.8.33;

import {SqrtRatio} from "ekubo/src/types/sqrtRatio.sol";
import {createSwapParameters} from "ekubo/src/types/swapParameters.sol";
import {EkuboGasTest} from "./EkuboGas.t.sol";

/// @notice Dedicated single-call capture for flamegraphs (no warm-up, no snapshot).
contract FlameTest is EkuboGasTest {
    function test_flame_single() public {
        router.swapAllowPartialFill(keyAB, createSwapParameters(SqrtRatio.wrap(0), 1 ether, false, 0));
    }
}
