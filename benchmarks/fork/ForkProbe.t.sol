// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";

contract ForkProbeTest is Test {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    IPoolManager constant MANAGER = IPoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function test_probe_weth_usdc_pools() public view {
        uint24[4] memory fees = [uint24(100), uint24(500), uint24(3000), uint24(10000)];
        int24[4] memory spacings = [int24(1), int24(10), int24(60), int24(200)];
        for (uint256 i = 0; i < 4; i++) {
            PoolKey memory key = PoolKey({
                currency0: Currency.wrap(USDC),
                currency1: Currency.wrap(WETH),
                fee: fees[i],
                tickSpacing: spacings[i],
                hooks: IHooks(address(0))
            });
            PoolId id = key.toId();
            uint128 liq = MANAGER.getLiquidity(id);
            (uint160 sqrtP, int24 tick,,) = MANAGER.getSlot0(id);
            console2.log("fee", fees[i]);
            console2.log("liquidity", liq);
            console2.log("tick", uint256(int256(tick)));
            sqrtP;
        }
    }
}
