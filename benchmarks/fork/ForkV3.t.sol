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

/// @notice Mainnet-fork validation: REAL SwapRouter + REAL USDT/USDC fee-100 pool
///         (deepest at the pinned block), 1000 USDT exact input, warmed with one
///         identical unmeasured swap (steady state).
///         USDT returns no returndata: approve via low-level call.
///         Run with: --fork-url <mainnet> --fork-block-number <pinned>
contract ForkV3Test is Test {
    ISwapRouter constant ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function _swap() internal returns (uint256) {
        return ROUTER.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: USDT,
                tokenOut: USDC,
                fee: 100,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: 1000000000,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function test_fork_single_exactInput_usdt() public {
        deal(USDT, address(this), 1000000000000);
        (bool approved,) =
            USDT.call(abi.encodeWithSignature("approve(address,uint256)", address(ROUTER), type(uint256).max));
        assertTrue(approved, "usdt approve");
        _swap(); // warm-up, unmeasured
        uint256 out = _swap(); // measured
        assertGt(out, 0);
        vm.snapshotGasLastCall("fork v3 SwapRouter 1000 USDT->USDC fee-100");
        // sanity: stable pair near parity (1000 USDT in, ~1000 USDC out)
        assertGe(out, 990000000);
        assertLe(out, 1005000000);
    }
}
