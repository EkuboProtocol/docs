// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {Test} from "forge-std/Test.sol";

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

/// @notice Mainnet-fork validation against a REAL live Ekubo pool (USDC/USDT,
///         concentrated, spacing 50, core-only extension) through the REAL
///         production Yul router, with SDK-generated calldata (see below).
///         One unmeasured warm-up swap precedes the measured swap (steady state);
///         every call runs isolated in its own EVM context, so the snapshot is the
///         execution gas of the measured swap (net of refunds, excluding the 21,000
///         base and calldata) with cold access at the start.
///
///         Calldata generated with the yul-router SDK (`encode-yul-route.mjs`):
///           encodeRoute({ specifiedToken: USDT, calculatedToken: USDC,
///             specifiedAmount, calculatedAmountThreshold = 99% of it,
///             recipient = this test contract, one core hop on the pool key below })
///         Run with: --fork-url <mainnet> --fork-block-number 25991868
contract ForkEkuboRealTest is Test {
    address constant YUL_ROUTER = 0x7B2aA7Ecc0B5936b7C52E6259A19C3BA557d0748;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Pool: token0 USDC, token1 USDT, concentrated spacing 50, no extension,
    // fee 0x53e2d6238da4 / 2^64 (0.0005%).
    // Config: 0x0000000000000000000000000000000000000000000053e2d6238da480000032
    bytes constant ROUTE_1000 = hex"0100dAC17F958D2ee523a2206206994597C13D831ec7A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB480000000000000000000000003b0233807FA9385bE102ac3EAc297483Dd6233D62b3e14960000000000000000000000003b9aca000000A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48dAC17F958D2ee523a2206206994597C13D831ec70000000000000000000000000000000000000000000053e2d6238da48000003200000000000000000000000000000000";
    bytes constant ROUTE_100 = hex"0100dAC17F958D2ee523a2206206994597C13D831ec7A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB4800000000000000000000000005e69ec07FA9385bE102ac3EAc297483Dd6233D62b3e149600000000000000000000000005f5e1000000A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48dAC17F958D2ee523a2206206994597C13D831ec70000000000000000000000000000000000000000000053e2d6238da48000003200000000000000000000000000000000";

    function _setup() internal {
        assertEq(address(this), 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496, "route recipient is this contract");
        deal(USDT, address(this), 1000000000000);
        // USDT returns no returndata: approve via low-level call, not a
        // bool-returning interface (which would revert on decoding).
        (bool approved,) = USDT.call(
            abi.encodeWithSignature("approve(address,uint256)", YUL_ROUTER, type(uint256).max)
        );
        assertTrue(approved, "usdt approve");
        assertEq(IERC20Like(USDT).allowance(address(this), YUL_ROUTER), type(uint256).max, "max approval");
    }

    function _swap(bytes memory route, string memory snapshotName) internal returns (uint256 out) {
        uint256 usdcBefore = IERC20Like(USDC).balanceOf(address(this));
        (bool ok, bytes memory ret) = YUL_ROUTER.call(route);
        if (bytes(snapshotName).length > 0) vm.snapshotGasLastCall(snapshotName);
        assertTrue(ok, "swap");
        (, , , int256 calculated) = abi.decode(ret, (address, address, int256, int256));
        assertGt(calculated, 0);
        out = IERC20Like(USDC).balanceOf(address(this)) - usdcBefore;
    }

    /// forge-config: default.isolate = true
    function test_fork_realPool_yulRouter_1000() public {
        _setup();
        uint256 warm = _swap(ROUTE_1000, ""); // warm-up: steady state, unmeasured
        assertGt(IERC20Like(USDC).balanceOf(address(this)), 0, "recipient USDC balance nonzero before measured swap");
        uint256 out = _swap(ROUTE_1000, "fork ekubo Yul router 1000 USDT->USDC live pool");
        vm.snapshotValue("fork ekubo output 1000 USDT->USDC (USDC, 6 decimals)", out);
        emit log_named_uint("ekubo warm-up output (USDC)", warm);
        emit log_named_uint("ekubo measured output (USDC)", out);
        // production quoter quoted ~999.36 USDC for this size; stay within 1%
        assertGe(out, 989000000);
        assertLe(out, 1009000000);
    }

    /// forge-config: default.isolate = true
    function test_fork_realPool_yulRouter_100() public {
        _setup();
        _swap(ROUTE_100, "");
        uint256 out = _swap(ROUTE_100, "fork ekubo Yul router 100 USDT->USDC live pool");
        vm.snapshotValue("fork ekubo output 100 USDT->USDC (USDC, 6 decimals)", out);
        emit log_named_uint("ekubo measured output (USDC)", out);
        assertGe(out, 98900000);
        assertLe(out, 100900000);
    }
}
