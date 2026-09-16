// SPDX-License-Identifier: ekubo-license-v1.eth
pragma solidity =0.8.33;

import {Test} from "forge-std/Test.sol";
import {ICore} from "ekubo/src/interfaces/ICore.sol";
import {Core} from "ekubo/src/Core.sol";
import {Positions} from "ekubo/src/Positions.sol";
import {Router} from "ekubo/src/Router.sol";
import {PoolKey} from "ekubo/src/types/poolKey.sol";
import {createConcentratedPoolConfig} from "ekubo/src/types/poolConfig.sol";
import {SqrtRatio} from "ekubo/src/types/sqrtRatio.sol";
import {Core} from "ekubo/src/Core.sol";
import {createSwapParameters} from "ekubo/src/types/swapParameters.sol";
import {PoolBalanceUpdate} from "ekubo/src/types/poolBalanceUpdate.sol";

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Mainnet-fork validation: REAL Core + REAL WETH/USDC + fresh full-range
///         0.3% pool capitalized on-fork; Router/Positions use production bytecode.
///         Run with: --fork-url <mainnet> --fork-block-number <pinned>
contract ForkEkuboTest is Test {
    ICore constant CORE = ICore(payable(0x00000000000014aA86C5d3c41765bb24e11bd701));
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint64 constant FEE_0_3 = 55340232221128655;
    // Same concentrated shape as the lab harness: spacing 6000, wide range.
    // Initialized at the raw WETH/USDC price (~4000 USDC per WETH, 6 vs 18
    // decimals) so the capitalized amounts are value-balanced and the measured
    // swap stays in range without crossing initialized ticks.
    uint32 constant TICK_SPACING = 6000;
    int32 constant RANGE_LOWER = -88722000;
    int32 constant RANGE_UPPER = 88722000;
    int32 constant INIT_TICK = 19337510; // raw WETH/USDC price (~4000 USDC per WETH
    // with 6 vs 18 decimals); Ekubo ticks rise with the token0/token1 raw price

    function test_fork_single_exactInput_weth() public {
        Positions positions = new Positions(CORE, address(this), 0, 1);
        Router router = new Router(CORE, address(0), address(0));

        // USDC < WETH, so token0 = USDC, token1 = WETH
        PoolKey memory key = PoolKey({
            token0: USDC,
            token1: WETH,
            config: createConcentratedPoolConfig(FEE_0_3, TICK_SPACING, address(0))
        });
        CORE.initializePool(key, INIT_TICK);

        deal(WETH, address(this), 2000 ether);
        deal(USDC, address(this), 8_000_000e6);
        IERC20Like(WETH).approve(address(positions), type(uint256).max);
        IERC20Like(USDC).approve(address(positions), type(uint256).max);
        IERC20Like(WETH).approve(address(router), type(uint256).max);
        positions.mintAndDeposit(key, RANGE_LOWER, RANGE_UPPER, 4_000_000e6, 1000 ether, 0);

        uint256 usdcBefore = IERC20Like(USDC).balanceOf(address(this));
        PoolBalanceUpdate update =
            router.swapAllowPartialFill(key, createSwapParameters(SqrtRatio.wrap(0), 1 ether, true, 0));
        assertEq(update.delta1(), 1 ether);
        assertGt(-update.delta0(), 0);
        vm.snapshotGasLastCall("fork ekubo Router 1 WETH->USDC concentrated 0.3%");
        assertGt(IERC20Like(USDC).balanceOf(address(this)), usdcBefore);
    }

    function test_fork_single_exactInput_freshCore() public {
        // Control: worktree Core (same bytecode as the lab harness) on fork state.
        Core fresh = new Core();
        Positions positions = new Positions(fresh, address(this), 0, 1);
        Router router = new Router(fresh, address(0), address(0));
        PoolKey memory key = PoolKey({
            token0: USDC,
            token1: WETH,
            config: createConcentratedPoolConfig(FEE_0_3, TICK_SPACING, address(0))
        });
        fresh.initializePool(key, INIT_TICK);
        deal(WETH, address(this), 2000 ether);
        deal(USDC, address(this), 8_000_000e6);
        IERC20Like(WETH).approve(address(positions), type(uint256).max);
        IERC20Like(USDC).approve(address(positions), type(uint256).max);
        IERC20Like(WETH).approve(address(router), type(uint256).max);
        positions.mintAndDeposit(key, RANGE_LOWER, RANGE_UPPER, 4_000_000e6, 1000 ether, 0);
        PoolBalanceUpdate update =
            router.swapAllowPartialFill(key, createSwapParameters(SqrtRatio.wrap(0), 1 ether, true, 0));
        assertEq(update.delta1(), 1 ether);
        vm.snapshotGasLastCall("fork ekubo fresh-Core 1 WETH->USDC concentrated 0.3%");
    }

    receive() external payable {}
}
