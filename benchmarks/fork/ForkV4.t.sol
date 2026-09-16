// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {Test} from "forge-std/Test.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {SwapParams} from "v4-core/src/types/PoolOperation.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IUnlockCallback} from "v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {TransientStateLibrary} from "v4-core/src/libraries/TransientStateLibrary.sol";
import {CurrencySettler} from "v4-core/test/utils/CurrencySettler.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";

/// @notice Minimal single-lock exact-input swapper over a live v4 pool.
///         Production Universal Router calldata would add overhead on top.
contract ForkSwapRouter is IUnlockCallback {
    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;
    using TransientStateLibrary for IPoolManager;

    IPoolManager public immutable manager;

    constructor(IPoolManager _manager) {
        manager = _manager;
    }

    function swap(PoolKey memory key, bool zeroForOne, int256 amountIn, uint160 limit, address payer)
        external
        payable
        returns (uint256 amountOut)
    {
        bytes memory result = manager.unlock(abi.encode(key, zeroForOne, amountIn, limit, payer, msg.sender));
        amountOut = abi.decode(result, (uint256));
    }

    function unlockCallback(bytes calldata rawData) external returns (bytes memory) {
        require(msg.sender == address(manager));
        (PoolKey memory key, bool zeroForOne, int256 amountIn, uint160 limit, address payer, address recipient) =
            abi.decode(rawData, (PoolKey, bool, int256, uint160, address, address));
        manager.swap(key, SwapParams({zeroForOne: zeroForOne, amountSpecified: amountIn, sqrtPriceLimitX96: limit}), "");
        Currency currencyIn = zeroForOne ? key.currency0 : key.currency1;
        Currency currencyOut = zeroForOne ? key.currency1 : key.currency0;
        int256 inDelta = manager.currencyDelta(address(this), currencyIn);
        int256 outDelta = manager.currencyDelta(address(this), currencyOut);
        if (inDelta < 0) currencyIn.settle(manager, payer, uint256(-inDelta), false);
        if (outDelta > 0) currencyOut.take(manager, recipient, uint256(outDelta), false);
        return abi.encode(uint256(outDelta));
    }
}

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Mainnet-fork validation: REAL PoolManager + REAL WETH/USDC pool,
///         deepest-hooked pool at the pinned block (fee 500, found by probe).
///         Run with: --fork-url <mainnet> --fork-block-number <pinned>
contract ForkV4Test is Test {
    IPoolManager constant MANAGER = IPoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function test_fork_single_exactInput_weth() public {
        ForkSwapRouter router = new ForkSwapRouter(MANAGER);
        // WETH is currency1 (USDC < WETH): WETH->USDC is oneForZero
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(WETH),
            fee: 500,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });
        deal(WETH, address(this), 10 ether);
        IERC20Like(WETH).approve(address(router), type(uint256).max);
        uint256 out = router.swap(key, false, -1 ether, TickMath.MAX_SQRT_PRICE - 1, address(this));
        assertGt(out, 0);
        vm.snapshotGasLastCall("fork v4 PoolManager 1 WETH->USDC fee-500");
    }
}
