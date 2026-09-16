// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {Test} from "forge-std/Test.sol";

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Mainnet-fork validation against a REAL live Ekubo pool (USDC/USDT,
///         concentrated, spacing 50, core-only extension) through the REAL
///         production Yul router, with SDK-generated calldata (see below).
///         One unmeasured warm-up swap precedes the measured swap (steady state),
///         and the size (1000 USDT) matches the production quoter.
///
///         Calldata generated with the yul-router SDK:
///           bun scripts/encode-once.mjs (encodeRoute, specifiedToken USDT,
///           calculatedToken USDC, specifiedAmount 1000000000,
///           calculatedAmountThreshold 990000000, recipient = test contract,
///           single core hop on the pool key below)
///         Run with: --fork-url <mainnet> --fork-block-number <pinned>
contract ForkEkuboRealTest is Test {
    address constant YUL_ROUTER = 0x7B2aA7Ecc0B5936b7C52E6259A19C3BA557d0748;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Pool: token0 USDC, token1 USDT, concentrated spacing 50, no extension.
    // Config: 0x0000000000000000000000000000000000000000000053e2d6238da480000032
    bytes constant ROUTE = hex"0100dAC17F958D2ee523a2206206994597C13D831ec7A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB480000000000000000000000003b0233807FA9385bE102ac3EAc297483Dd6233D62b3e14960000000000000000000000003b9aca000000A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48dAC17F958D2ee523a2206206994597C13D831ec70000000000000000000000000000000000000000000053e2d6238da48000003200000000000000000000000000000000";

    function test_fork_realPool_yulRouter() public {
        deal(USDT, address(this), 1000000000000);
        // USDT returns no returndata: approve via low-level call, not a
        // bool-returning interface (which would revert on decoding).
        (bool approved,) = USDT.call(
            abi.encodeWithSignature("approve(address,uint256)", YUL_ROUTER, type(uint256).max)
        );
        assertTrue(approved, "usdt approve");

        // warm-up: steady state, unmeasured
        (bool okWarm,) = YUL_ROUTER.call(ROUTE);
        assertTrue(okWarm, "warm-up swap");

        // measured leg
        uint256 usdcBefore = IERC20Like(USDC).balanceOf(address(this));
        (bool ok, bytes memory ret) = YUL_ROUTER.call(ROUTE);
        assertTrue(ok, "measured swap");
        vm.snapshotGasLastCall("fork ekubo Yul router live USDC/USDT pool");
        (, , , int256 calculated) = abi.decode(ret, (address, address, int256, int256));
        assertGt(calculated, 0);
        // production quoter quoted ~999.36 USDC for this size; stay within 1%
        uint256 out = IERC20Like(USDC).balanceOf(address(this)) - usdcBefore;
        assertGe(out, 989000000);
        assertLe(out, 1009000000);
    }
}
