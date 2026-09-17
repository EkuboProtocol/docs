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

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

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
        if (inDelta < 0) {
            // tolerant settlement: low-level transferFrom so non-standard
            // tokens (e.g. USDT, no returndata) work like on production routers
            manager.sync(currencyIn);
            (bool ok,) = Currency.unwrap(currencyIn).call(
                abi.encodeWithSignature(
                    "transferFrom(address,address,uint256)", payer, address(manager), uint256(-inDelta)
                )
            );
            require(ok, "transferFrom failed");
            manager.settle();
        }
        if (outDelta > 0) currencyOut.take(manager, recipient, uint256(outDelta), false);
        return abi.encode(uint256(outDelta));
    }
}

/// @notice Mainnet-fork validation: REAL PoolManager + REAL USDT/USDC fee-100 pool
///         (deepest at the pinned block, hooks = address(0)), exact input, warmed with
///         one identical unmeasured swap (steady state); every call runs isolated in its
///         own EVM context, so the snapshot is the execution gas of the measured swap
///         (net of refunds, excluding the 21,000 base and calldata).
///         Run with: --fork-url <mainnet> --fork-block-number 25991868
contract ForkV4Test is Test {
    IPoolManager constant MANAGER = IPoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    ForkSwapRouter router;
    PoolKey key;

    function _setup() internal {
        router = new ForkSwapRouter(MANAGER);
        // USDT is currency1 (USDC < USDT): USDT->USDC is oneForZero
        key = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(USDT),
            fee: 100,
            tickSpacing: 1,
            hooks: IHooks(address(0))
        });
        deal(USDT, address(this), 1000000000000);
        (bool approved,) =
            USDT.call(abi.encodeWithSignature("approve(address,uint256)", address(router), type(uint256).max));
        assertTrue(approved, "usdt approve");
        assertEq(IERC20Like(USDT).allowance(address(this), address(router)), type(uint256).max, "max approval");
    }

    function _swap(int256 amountIn) internal returns (uint256) {
        return router.swap(key, false, amountIn, TickMath.MAX_SQRT_PRICE - 1, address(this));
    }

    /// forge-config: default.isolate = true
    function test_fork_single_exactInput_usdt_1000() public {
        _setup();
        _swap(-1000000000); // warm-up
        assertGt(IERC20Like(USDC).balanceOf(address(this)), 0, "recipient USDC balance nonzero before measured swap");
        uint256 out = _swap(-1000000000); // measured
        vm.snapshotGasLastCall("fork v4 PoolManager 1000 USDT->USDC fee-100");
        vm.snapshotValue("fork v4 output 1000 USDT->USDC (USDC, 6 decimals)", out);
        emit log_named_uint("v4 measured output (USDC)", out);
        assertGe(out, 990000000);
        assertLe(out, 1005000000);
    }

    /// forge-config: default.isolate = true
    function test_fork_single_exactInput_usdt_100() public {
        _setup();
        _swap(-100000000);
        uint256 out = _swap(-100000000);
        vm.snapshotGasLastCall("fork v4 PoolManager 100 USDT->USDC fee-100");
        vm.snapshotValue("fork v4 output 100 USDT->USDC (USDC, 6 decimals)", out);
        emit log_named_uint("v4 measured output (USDC)", out);
        assertGe(out, 99000000);
        assertLe(out, 100500000);
    }
}
