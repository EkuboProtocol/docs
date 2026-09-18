// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {Test} from "forge-std/Test.sol";

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IWETH9 {
    function deposit() external payable;
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Mainnet-fork validation: REAL SwapRouter + REAL USDT/USDC fee-100 pool
///         (deepest at the pinned block), exact input, warmed with one identical
///         unmeasured swap (steady state); every call runs isolated in its own EVM
///         context, so the snapshot is the execution gas of the measured swap (net of
///         refunds, excluding the 21,000 base and calldata).
///         USDT returns no returndata: approve via low-level call. Run with: --fork-url <mainnet> --fork-block-number 25991868
contract ForkV3Test is Test {
    ISwapRouter constant ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    IWETH9 constant WETH = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function _setup() internal {
        deal(USDT, address(this), 1000000000000);
        (bool approved,) =
            USDT.call(abi.encodeWithSignature("approve(address,uint256)", address(ROUTER), type(uint256).max));
        assertTrue(approved, "usdt approve");
        assertEq(IERC20Like(USDT).allowance(address(this), address(ROUTER)), type(uint256).max, "max approval");
    }

    function _swap(uint256 amountIn) internal returns (uint256) {
        return ROUTER.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: USDT,
                tokenOut: USDC,
                fee: 100,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
    }

    /// forge-config: default.isolate = true
    function test_fork_single_exactInput_usdt_1000() public {
        _setup();
        _swap(1000000000); // warm-up, unmeasured
        assertGt(IERC20Like(USDC).balanceOf(address(this)), 0, "recipient USDC balance nonzero before measured swap");
        uint256 out = _swap(1000000000); // measured
        vm.snapshotGasLastCall("fork v3 SwapRouter 1000 USDT->USDC fee-100");
        vm.snapshotValue("fork v3 output 1000 USDT->USDC (USDC, 6 decimals)", out);
        emit log_named_uint("v3 measured output (USDC)", out);
        // sanity: stable pair near parity (1000 USDT in, ~1000 USDC out)
        assertGe(out, 990000000);
        assertLe(out, 1005000000);
    }

    /// forge-config: default.isolate = true
    function test_fork_single_exactInput_usdt_100() public {
        _setup();
        _swap(100000000);
        uint256 out = _swap(100000000);
        vm.snapshotGasLastCall("fork v3 SwapRouter 100 USDT->USDC fee-100");
        vm.snapshotValue("fork v3 output 100 USDT->USDC (USDC, 6 decimals)", out);
        emit log_named_uint("v3 measured output (USDC)", out);
        assertGe(out, 99000000);
        assertLe(out, 100500000);
    }

    /// @dev What a v3 user pays to wrap ETH before a native-input swap (v3 pools hold
    ///      WETH, not ETH). Steady state: the account already holds WETH (this address
    ///      does at the pinned block), so the balance write is nonzero -> nonzero.
    /// forge-config: default.isolate = true
    function test_fork_weth_deposit() public {
        vm.deal(address(this), 10 ether);
        uint256 before = WETH.balanceOf(address(this));
        assertGt(before, 0, "already holds WETH");
        WETH.deposit{value: 1 ether}(); // warm-up, unmeasured
        WETH.deposit{value: 1 ether}();
        vm.snapshotGasLastCall("fork WETH deposit steady-state");
        assertEq(WETH.balanceOf(address(this)), before + 2 ether);
    }
}
