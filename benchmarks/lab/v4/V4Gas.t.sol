// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IUnlockCallback} from "v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {TransientStateLibrary} from "v4-core/src/libraries/TransientStateLibrary.sol";
import {CurrencySettler} from "v4-core/test/utils/CurrencySettler.sol";
import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";

/// @notice True-minimal single-hop exact-input locker: unlock, swap, settle net.
///         No balance assertions, no test settings — the floor for v4 router cost.
///         Native input is settled with the value forwarded by the caller.
contract MinimalSwapRouter is IUnlockCallback {
    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;
    using TransientStateLibrary for IPoolManager;

    IPoolManager public immutable manager;

    constructor(IPoolManager _manager) {
        manager = _manager;
    }

    function swapExactIn(PoolKey memory key, bool zeroForOne, int256 amountIn, uint160 limit, address payer)
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

/// @notice Minimal single-lock N-hop exact-input router (e.g. A->B->C->D), mirroring
///         what a production v4 router does inside one `unlock` with net settlement.
contract MultiHopRouter is IUnlockCallback {
    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;
    using TransientStateLibrary for IPoolManager;

    IPoolManager public immutable manager;

    constructor(IPoolManager _manager) {
        manager = _manager;
    }

    struct Hop {
        PoolKey key;
        uint160 sqrtPriceLimitX96;
    }

    function multiHop(Hop[] memory hops, Currency currencyIn, Currency currencyOut, int256 amountIn)
        external
        payable
        returns (uint256 amountOut)
    {
        bytes memory result = manager.unlock(
            abi.encode(hops, currencyIn, currencyOut, amountIn, msg.sender, msg.sender)
        );
        amountOut = abi.decode(result, (uint256));
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) CurrencyLibrary.ADDRESS_ZERO.transfer(msg.sender, ethBalance);
    }

    function unlockCallback(bytes calldata rawData) external returns (bytes memory) {
        require(msg.sender == address(manager));
        (Hop[] memory hops, Currency currencyIn, Currency currencyOut, int256 amountIn, address payer, address recipient)
            = abi.decode(rawData, (Hop[], Currency, Currency, int256, address, address));

        Currency currencyOwed = currencyIn;
        int256 amountOwed = amountIn;
        for (uint256 i = 0; i < hops.length; i++) {
            bool zeroForOne = currencyOwed == hops[i].key.currency0;
            manager.swap(
                hops[i].key,
                SwapParams({zeroForOne: zeroForOne, amountSpecified: amountOwed, sqrtPriceLimitX96: hops[i].sqrtPriceLimitX96}),
                ""
            );
            currencyOwed = zeroForOne ? hops[i].key.currency1 : hops[i].key.currency0;
            amountOwed = -manager.currencyDelta(address(this), currencyOwed);
            require(amountOwed < 0, "no hop output");
        }

        int256 inDelta = manager.currencyDelta(address(this), currencyIn);
        int256 outDelta = manager.currencyDelta(address(this), currencyOut);
        require(inDelta <= 0, "inDelta positive");
        require(outDelta >= 0, "outDelta negative");
        if (inDelta < 0) currencyIn.settle(manager, payer, uint256(-inDelta), false);
        if (outDelta > 0) currencyOut.take(manager, recipient, uint256(outDelta), false);
        return abi.encode(uint256(outDelta));
    }
}

contract V4GasTest is Test {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    PoolManager manager;
    PoolSwapTest swapRouter;
    MinimalSwapRouter minRouter;
    PoolModifyLiquidityTest mintRouter;
    MultiHopRouter multiHopRouter;

    MockERC20 tokenA;
    MockERC20 tokenB;
    MockERC20 tokenC;
    MockERC20 tokenD;

    PoolKey keyAB;
    PoolKey keyBC;
    PoolKey keyCD;
    PoolKey keyNative;

    int24 constant TICK_LOWER = -887220;
    int24 constant TICK_UPPER = 887220;
    uint256 constant LIQUIDITY_TOKEN_AMOUNT = 1_000_000 ether;
    int256 constant SWAP_AMOUNT = -1 ether;

    function setUp() public virtual {
        manager = new PoolManager(address(this));
        swapRouter = new PoolSwapTest(manager);
        minRouter = new MinimalSwapRouter(manager);
        mintRouter = new PoolModifyLiquidityTest(manager);
        multiHopRouter = new MultiHopRouter(manager);

        // One identical token artifact (solmate MockERC20, deployed via deployCode)
        // in every harness, so transfer costs cannot skew the comparison.
        tokenA = MockERC20(vm.deployCode("artifacts/MockERC20.json", abi.encode("TokenA", "A", 18)));
        tokenB = MockERC20(vm.deployCode("artifacts/MockERC20.json", abi.encode("TokenB", "B", 18)));
        tokenC = MockERC20(vm.deployCode("artifacts/MockERC20.json", abi.encode("TokenC", "C", 18)));
        tokenD = MockERC20(vm.deployCode("artifacts/MockERC20.json", abi.encode("TokenD", "D", 18)));
        // sort A < B < C < D by address for valid v4 currency ordering
        if (address(tokenA) > address(tokenB)) (tokenA, tokenB) = (tokenB, tokenA);
        if (address(tokenC) > address(tokenD)) (tokenC, tokenD) = (tokenD, tokenC);
        if (address(tokenB) > address(tokenC)) (tokenB, tokenC) = (tokenC, tokenB);
        if (address(tokenA) > address(tokenB)) (tokenA, tokenB) = (tokenB, tokenA);
        if (address(tokenC) > address(tokenD)) (tokenC, tokenD) = (tokenD, tokenC);

        tokenA.mint(address(this), 10_000_000 ether);
        tokenB.mint(address(this), 10_000_000 ether);
        tokenC.mint(address(this), 10_000_000 ether);
        tokenD.mint(address(this), 10_000_000 ether);
        vm.deal(address(this), 10_000_000 ether);

        tokenA.approve(address(swapRouter), type(uint256).max);
        tokenB.approve(address(swapRouter), type(uint256).max);
        tokenC.approve(address(swapRouter), type(uint256).max);
        tokenA.approve(address(mintRouter), type(uint256).max);
        tokenB.approve(address(mintRouter), type(uint256).max);
        tokenC.approve(address(mintRouter), type(uint256).max);
        tokenD.approve(address(mintRouter), type(uint256).max);
        tokenA.approve(address(multiHopRouter), type(uint256).max);
        tokenA.approve(address(minRouter), type(uint256).max);
        tokenB.approve(address(minRouter), type(uint256).max);

        keyAB = _key(address(tokenA), address(tokenB));
        keyBC = _key(address(tokenB), address(tokenC));
        keyCD = _key(address(tokenC), address(tokenD));

        manager.initialize(keyAB, TickMath.getSqrtPriceAtTick(30));
        manager.initialize(keyBC, TickMath.getSqrtPriceAtTick(30));
        manager.initialize(keyCD, TickMath.getSqrtPriceAtTick(30));
        _addFullRangeLiquidity(keyAB);
        _addFullRangeLiquidity(keyBC);
        _addFullRangeLiquidity(keyCD);

        // native (ETH) / tokenB pool for the native-input scenario
        keyNative = _key(address(0), address(tokenB));
        manager.initialize(keyNative, TickMath.getSqrtPriceAtTick(30));
        mintRouter.modifyLiquidity{value: LIQUIDITY_TOKEN_AMOUNT}(
            keyNative,
            ModifyLiquidityParams({tickLower: TICK_LOWER, tickUpper: TICK_UPPER, liquidityDelta: int256(uint256(_fullRangeLiquidity(LIQUIDITY_TOKEN_AMOUNT, LIQUIDITY_TOKEN_AMOUNT))), salt: bytes32(0)}),
            ""
        );
    }

    function _key(address c0, address c1) internal pure returns (PoolKey memory) {
        return PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
    }

    function _fullRangeLiquidity(uint256 amount0, uint256 amount1) internal pure returns (uint128) {
        uint160 sqrtA = TickMath.getSqrtPriceAtTick(TICK_LOWER);
        uint160 sqrtB = TickMath.getSqrtPriceAtTick(TICK_UPPER);
        return LiquidityAmounts.getLiquidityForAmounts(TickMath.getSqrtPriceAtTick(30), sqrtA, sqrtB, amount0, amount1);
    }

    function _addFullRangeLiquidity(PoolKey memory key) internal {
        uint128 liq = _fullRangeLiquidity(LIQUIDITY_TOKEN_AMOUNT, LIQUIDITY_TOKEN_AMOUNT);
        mintRouter.modifyLiquidity(
            key,
            ModifyLiquidityParams({tickLower: TICK_LOWER, tickUpper: TICK_UPPER, liquidityDelta: int256(uint256(liq)), salt: bytes32(0)}),
            ""
        );
    }

    function _v4Hops(PoolKey[] memory keys) internal pure returns (MultiHopRouter.Hop[] memory hops) {
        hops = new MultiHopRouter.Hop[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            hops[i] = MultiHopRouter.Hop({key: keys[i], sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1});
        }
    }

    function _swapAB() internal returns (uint256) {
        return minRouter.swapExactIn(keyAB, true, SWAP_AMOUNT, TickMath.MIN_SQRT_PRICE + 1, address(this));
    }

    // ---- single swaps through the minimal locker ----

    /// forge-config: default.isolate = true
    function test_gas_single_steady_erc20() public {
        _swapAB(); // warm-up, unmeasured
        uint256 out = _swapAB();
        assertGt(out, 0);
        vm.snapshotGasLastCall("v4 single erc20 steady-state");
    }

    /// forge-config: default.isolate = true
    function test_gas_single_steady_erc20_reverse() public {
        minRouter.swapExactIn(keyAB, false, SWAP_AMOUNT, TickMath.MAX_SQRT_PRICE - 1, address(this));
        uint256 out = minRouter.swapExactIn(keyAB, false, SWAP_AMOUNT, TickMath.MAX_SQRT_PRICE - 1, address(this));
        assertGt(out, 0);
        vm.snapshotGasLastCall("v4 single erc20 reverse steady-state");
    }

    /// forge-config: default.isolate = true
    function test_gas_single_steady_native() public {
        minRouter.swapExactIn{value: 1 ether}(keyNative, true, SWAP_AMOUNT, TickMath.MIN_SQRT_PRICE + 1, address(this));
        uint256 out = minRouter.swapExactIn{value: 1 ether}(keyNative, true, SWAP_AMOUNT, TickMath.MIN_SQRT_PRICE + 1, address(this));
        assertGt(out, 0);
        vm.snapshotGasLastCall("v4 single native steady-state");
    }

    /// @dev No warm-up: the very first swap in a freshly capitalized pool, which writes the
    ///      fee-growth accumulator from zero (SSTORE 20,000 instead of 2,900).
    /// forge-config: default.isolate = true
    function test_gas_single_firstSwap_erc20() public {
        uint256 out = _swapAB();
        assertGt(out, 0);
        vm.snapshotGasLastCall("v4 single erc20 first swap in fresh pool");
    }

    /// @dev Context only: v4-core's own PoolSwapTest helper (balance assertions and test
    ///      settings) on the same swap, to show the minimal locker is the floor.
    /// forge-config: default.isolate = true
    function test_gas_single_steady_erc20_poolSwapTest() public {
        SwapParams memory params =
            SwapParams({zeroForOne: true, amountSpecified: SWAP_AMOUNT, sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1});
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});
        swapRouter.swap(keyAB, params, settings, "");
        swapRouter.swap(keyAB, params, settings, "");
        vm.snapshotGasLastCall("v4 single erc20 steady-state PoolSwapTest helper");
    }

    // ---- routes through the single-lock multihop router, warmed ----

    function _route(uint256 n) internal returns (uint256 out) {
        PoolKey[] memory keys = new PoolKey[](n);
        keys[0] = keyAB;
        if (n > 1) keys[1] = keyBC;
        if (n > 2) keys[2] = keyCD;
        Currency currencyOut = Currency.wrap(address(n == 1 ? tokenB : n == 2 ? tokenC : tokenD));
        out = multiHopRouter.multiHop(_v4Hops(keys), Currency.wrap(address(tokenA)), currencyOut, SWAP_AMOUNT);
    }

    /// forge-config: default.isolate = true
    function test_gas_route_1pool() public {
        _route(1);
        assertGt(_route(1), 0);
        vm.snapshotGasLastCall("v4 route 1 pool steady-state");
    }

    /// forge-config: default.isolate = true
    function test_gas_route_2pools() public {
        _route(2);
        assertGt(_route(2), 0);
        vm.snapshotGasLastCall("v4 route 2 pools steady-state");
    }

    /// forge-config: default.isolate = true
    function test_gas_route_3pools() public {
        _route(3);
        assertGt(_route(3), 0);
        vm.snapshotGasLastCall("v4 route 3 pools steady-state");
    }

    // ---- liquidity provision through v4-core's PoolModifyLiquidityTest ----

    /// @dev Warm-up mint under one salt, measured mint under another: a brand-new position
    ///      with both boundary ticks already initialized.
    /// forge-config: default.isolate = true
    function test_gas_mint_newPosition() public {
        uint128 liq = _fullRangeLiquidity(LIQUIDITY_TOKEN_AMOUNT, LIQUIDITY_TOKEN_AMOUNT);
        mintRouter.modifyLiquidity(
            keyAB,
            ModifyLiquidityParams({tickLower: TICK_LOWER, tickUpper: TICK_UPPER, liquidityDelta: int256(uint256(liq)), salt: bytes32(uint256(2))}),
            ""
        );
        mintRouter.modifyLiquidity(
            keyAB,
            ModifyLiquidityParams({tickLower: TICK_LOWER, tickUpper: TICK_UPPER, liquidityDelta: int256(uint256(liq)), salt: bytes32(uint256(1))}),
            ""
        );
        vm.snapshotGasLastCall("v4 mint new position");
    }

    // ---- pool creation ----

    /// forge-config: default.isolate = true
    function test_gas_initializePool() public {
        manager.initialize(_key(address(tokenA), address(tokenD)), TickMath.getSqrtPriceAtTick(30));
        vm.snapshotGasLastCall("v4 initialize pool");
    }

    receive() external payable {}
}
