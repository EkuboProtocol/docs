// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";

interface IUniswapV3FactoryLike {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IUniswapV3PoolLike {
    function liquidity() external view returns (uint128);
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
}

/// @notice Identifies the three fork pools at the pinned block: address / id, fee,
///         spacing, hooks (v4), in-range liquidity and current tick, so the fork numbers
///         can be tied to concrete on-chain state. Read-only.
///         Run with: --fork-url <mainnet> --fork-block-number 25991868
contract ForkProbeTest is Test {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    IPoolManager constant MANAGER = IPoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);
    IUniswapV3FactoryLike constant V3_FACTORY = IUniswapV3FactoryLike(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    address constant EKUBO_CORE = 0x00000000000014aA86C5d3c41765bb24e11bd701;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    bytes32 constant EKUBO_CONFIG = 0x0000000000000000000000000000000000000000000053e2d6238da480000032;

    function test_probe_block() public view {
        console2.log("block", block.number);
        console2.log("timestamp", block.timestamp);
    }

    function test_probe_usdt_usdc_pools_v4() public view {
        uint24[3] memory fees = [uint24(100), uint24(500), uint24(3000)];
        int24[3] memory spacings = [int24(1), int24(10), int24(60)];
        for (uint256 i = 0; i < 3; i++) {
            PoolKey memory key = PoolKey({
                currency0: Currency.wrap(USDC),
                currency1: Currency.wrap(USDT),
                fee: fees[i],
                tickSpacing: spacings[i],
                hooks: IHooks(address(0))
            });
            PoolId id = key.toId();
            uint128 liq = MANAGER.getLiquidity(id);
            (uint160 sqrtP, int24 tick,,) = MANAGER.getSlot0(id);
            console2.log("v4 fee", fees[i]);
            console2.logBytes32(PoolId.unwrap(id));
            console2.log("v4 initialized (sqrtPrice != 0, hooks = 0)", sqrtP != 0);
            console2.log("v4 liquidity", liq);
            console2.log("v4 tick", tick);
        }
    }

    function test_probe_usdt_usdc_pools_v3() public view {
        uint24[3] memory fees = [uint24(100), uint24(500), uint24(3000)];
        for (uint256 i = 0; i < 3; i++) {
            address pool = V3_FACTORY.getPool(USDC, USDT, fees[i]);
            console2.log("v3 fee", fees[i]);
            console2.log("v3 pool", pool);
            if (pool == address(0)) continue;
            (, int24 tick,, uint16 cardinality,,,) = IUniswapV3PoolLike(pool).slot0();
            console2.log("v3 liquidity", IUniswapV3PoolLike(pool).liquidity());
            console2.log("v3 tick", tick);
            console2.log("v3 observation cardinality", cardinality);
        }
    }

    /// @dev Core stores the packed pool state at slot `poolId = keccak256(token0, token1, config)`:
    ///      sqrtRatio (96 bits) | tick (32 bits) | liquidity (128 bits).
    function test_probe_usdc_usdt_pool_ekubo() public view {
        bytes32 poolId = keccak256(abi.encode(USDC, USDT, EKUBO_CONFIG));
        bytes32 state = vm.load(EKUBO_CORE, poolId);
        uint256 sqrtRatio = uint256(state) >> 160;
        int32 tick = int32(uint32((uint256(state) >> 128) & 0xffffffff));
        uint128 liq = uint128(uint256(state));
        uint64 fee = uint64((uint256(EKUBO_CONFIG) >> 32) & 0xffffffffffffffff);
        console2.log("ekubo config fee (Q64)", fee);
        console2.log("ekubo config tick spacing", uint256(EKUBO_CONFIG) & 0x7fffffff);
        console2.log("ekubo config concentrated", (uint256(EKUBO_CONFIG) & 0x80000000) != 0);
        console2.logBytes32(poolId);
        console2.log("ekubo sqrtRatio raw (96-bit)", sqrtRatio);
        console2.log("ekubo tick", tick);
        console2.log("ekubo liquidity", liq);
        assertTrue(state != bytes32(0), "pool initialized");
    }
}
