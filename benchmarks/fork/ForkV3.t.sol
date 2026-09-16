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
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Mainnet-fork validation: REAL SwapRouter + REAL WETH/USDC 0.3% pool.
///         Run with: --fork-url <mainnet> --fork-block-number <pinned>
contract ForkV3Test is Test {
    ISwapRouter constant ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function test_fork_single_exactInput_weth() public {
        deal(WETH, address(this), 10 ether);
        IERC20Like(WETH).approve(address(ROUTER), type(uint256).max);
        uint256 out = ROUTER.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: USDC,
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: 1 ether,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
        assertGt(out, 0);
        vm.snapshotGasLastCall("fork v3 SwapRouter 1 WETH->USDC 0.3%");
    }
}
