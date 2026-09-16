// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
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

        keyAB = PoolKey({
            currency0: Currency.wrap(address(tokenA)),
            currency1: Currency.wrap(address(tokenB)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        keyBC = PoolKey({
            currency0: Currency.wrap(address(tokenB)),
            currency1: Currency.wrap(address(tokenC)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        keyCD = PoolKey({
            currency0: Currency.wrap(address(tokenC)),
            currency1: Currency.wrap(address(tokenD)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        manager.initialize(keyAB, TickMath.getSqrtPriceAtTick(30));
        manager.initialize(keyBC, TickMath.getSqrtPriceAtTick(30));
        manager.initialize(keyCD, TickMath.getSqrtPriceAtTick(30));
        _addFullRangeLiquidity(keyAB, address(tokenA), address(tokenB), false);
        _addFullRangeLiquidity(keyBC, address(tokenB), address(tokenC), false);
        _addFullRangeLiquidity(keyCD, address(tokenC), address(tokenD), false);

        // native (ETH) / tokenB pool for the native-input scenario
        keyNative = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(tokenB)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        manager.initialize(keyNative, TickMath.getSqrtPriceAtTick(30));
        tokenB.approve(address(mintRouter), type(uint256).max);
        mintRouter.modifyLiquidity{value: LIQUIDITY_TOKEN_AMOUNT}(
            keyNative,
            ModifyLiquidityParams({tickLower: TICK_LOWER, tickUpper: TICK_UPPER, liquidityDelta: int256(uint256(_fullRangeLiquidity(LIQUIDITY_TOKEN_AMOUNT, LIQUIDITY_TOKEN_AMOUNT))), salt: bytes32(0)}),
            ""
        );

    }

    function _fullRangeLiquidity(uint256 amount0, uint256 amount1) internal pure returns (uint128) {
        uint160 sqrtA = TickMath.getSqrtPriceAtTick(TICK_LOWER);
        uint160 sqrtB = TickMath.getSqrtPriceAtTick(TICK_UPPER);
        return LiquidityAmounts.getLiquidityForAmounts(TickMath.getSqrtPriceAtTick(30), sqrtA, sqrtB, amount0, amount1);
    }

    function _addFullRangeLiquidity(PoolKey memory key, address t0, address t1, bool native) internal {
        uint128 liq = _fullRangeLiquidity(LIQUIDITY_TOKEN_AMOUNT, LIQUIDITY_TOKEN_AMOUNT);
        if (native) {
            mintRouter.modifyLiquidity{value: LIQUIDITY_TOKEN_AMOUNT}(
                key,
                ModifyLiquidityParams({tickLower: TICK_LOWER, tickUpper: TICK_UPPER, liquidityDelta: int256(uint256(liq)), salt: bytes32(0)}),
                ""
            );
        } else {
            mintRouter.modifyLiquidity(
                key,
                ModifyLiquidityParams({tickLower: TICK_LOWER, tickUpper: TICK_UPPER, liquidityDelta: int256(uint256(liq)), salt: bytes32(0)}),
                ""
            );
        }
        (t0, t1);
    }

    function _v4Hops(PoolKey[] memory keys) internal pure returns (MultiHopRouter.Hop[] memory hops) {
        hops = new MultiHopRouter.Hop[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            hops[i] = MultiHopRouter.Hop({key: keys[i], sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1});
        }
    }

    /// forge-config: default.isolate = true
    function test_gas_single_minimal_erc20() public {
        minRouter.swapExactIn(keyAB, true, SWAP_AMOUNT, TickMath.MIN_SQRT_PRICE + 1, address(this));
        uint256 out = minRouter.swapExactIn(keyAB, true, SWAP_AMOUNT, TickMath.MIN_SQRT_PRICE + 1, address(this));
        assertGt(out, 0);
        vm.snapshotGasLastCall("v4 single exact-input minimal locker token0->token1");
    }

    /// forge-config: default.isolate = true
    function test_gas_single_minimal_erc20_reverse() public {
        minRouter.swapExactIn(keyAB, false, SWAP_AMOUNT, TickMath.MAX_SQRT_PRICE - 1, address(this));
        uint256 out = minRouter.swapExactIn(keyAB, false, SWAP_AMOUNT, TickMath.MAX_SQRT_PRICE - 1, address(this));
        assertGt(out, 0);
        vm.snapshotGasLastCall("v4 single exact-input minimal locker token1->token0");
    }

    /// forge-config: default.isolate = true
    function test_gas_single_exactInput_erc20() public {
        swapRouter.swap(
            keyAB,
            SwapParams({zeroForOne: true, amountSpecified: SWAP_AMOUNT, sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        swapRouter.swap(
            keyAB,
            SwapParams({zeroForOne: true, amountSpecified: SWAP_AMOUNT, sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        vm.snapshotGasLastCall("v4 single exact-input ERC20->ERC20 wide-range concentrated");
    }

    /// forge-config: default.isolate = true
    function test_gas_single_exactInput_native() public {
        swapRouter.swap{value: 1 ether}(
            keyNative,
            SwapParams({zeroForOne: true, amountSpecified: SWAP_AMOUNT, sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        swapRouter.swap{value: 1 ether}(
            keyNative,
            SwapParams({zeroForOne: true, amountSpecified: SWAP_AMOUNT, sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        vm.snapshotGasLastCall("v4 single exact-input native->ERC20 wide-range concentrated");
    }

    /// forge-config: default.isolate = true
    function test_gas_oneHop_exactInput() public {
        PoolKey[] memory keys = new PoolKey[](1);
        keys[0] = keyAB;
        multiHopRouter.multiHop(_v4Hops(keys), Currency.wrap(address(tokenA)), Currency.wrap(address(tokenB)), SWAP_AMOUNT);
        uint256 out = multiHopRouter.multiHop(_v4Hops(keys), Currency.wrap(address(tokenA)), Currency.wrap(address(tokenB)), SWAP_AMOUNT);
        assertGt(out, 0);
        vm.snapshotGasLastCall("v4 one-hop exact-input single lock");
    }

    /// forge-config: default.isolate = true
    function test_gas_twoHop_exactInput() public {
        PoolKey[] memory keys = new PoolKey[](2);
        keys[0] = keyAB;
        keys[1] = keyBC;
        multiHopRouter.multiHop(_v4Hops(keys), Currency.wrap(address(tokenA)), Currency.wrap(address(tokenC)), SWAP_AMOUNT);
        uint256 out = multiHopRouter.multiHop(_v4Hops(keys), Currency.wrap(address(tokenA)), Currency.wrap(address(tokenC)), SWAP_AMOUNT);
        assertGt(out, 0);
        vm.snapshotGasLastCall("v4 two-hop exact-input single lock");
    }

    /// forge-config: default.isolate = true
    function test_gas_threeHop_exactInput() public {
        PoolKey[] memory keys = new PoolKey[](3);
        keys[0] = keyAB;
        keys[1] = keyBC;
        keys[2] = keyCD;
        multiHopRouter.multiHop(_v4Hops(keys), Currency.wrap(address(tokenA)), Currency.wrap(address(tokenD)), SWAP_AMOUNT);
        uint256 out = multiHopRouter.multiHop(_v4Hops(keys), Currency.wrap(address(tokenA)), Currency.wrap(address(tokenD)), SWAP_AMOUNT);
        assertGt(out, 0);
        vm.snapshotGasLastCall("v4 three-hop exact-input single lock");
    }

    /// forge-config: default.isolate = true
    function test_gas_mint_fullRange() public {
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
        vm.snapshotGasLastCall("v4 mint wide-range position");
    }

    receive() external payable {}
}
