// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {ProdCommon, IFreshToken} from "./ProdCommon.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IUnlockCallback} from "v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {TransientStateLibrary} from "v4-core/src/libraries/TransientStateLibrary.sol";
import {CurrencySettler} from "v4-core/test/utils/CurrencySettler.sol";
import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";

interface IPermit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}

/// @notice Minimal single-lock N-hop exact-input router (e.g. A->B->C->D) with net
///         settlement: unlock, swap each hop, settle the input once, take the output once.
///         Same contract as in the lab harness; the like-for-like counterpart of the
///         Ekubo minimal locker.
contract V4MinimalRouter is IUnlockCallback {
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
        bytes memory result = manager.unlock(abi.encode(hops, currencyIn, currencyOut, amountIn, msg.sender, msg.sender));
        amountOut = abi.decode(result, (uint256));
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) CurrencyLibrary.ADDRESS_ZERO.transfer(msg.sender, ethBalance);
    }

    function unlockCallback(bytes calldata rawData) external returns (bytes memory) {
        require(msg.sender == address(manager));
        (Hop[] memory hops, Currency currencyIn, Currency currencyOut, int256 amountIn, address payer, address recipient) =
            abi.decode(rawData, (Hop[], Currency, Currency, int256, address, address));

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

/// @notice Production Uniswap v4 on a fork of the latest mainnet block, fresh tokens: the
///         deployed PoolManager holds the pools, the deployed Universal Router (funded
///         through Permit2, the path the Uniswap interface sends) is the production path,
///         the minimal router above is the lab counterpart. Full-range positions of 1M/1M
///         tokens per pool, added through v4-core's PoolModifyLiquidityTest in setup
///         (unmeasured). One identical unmeasured call precedes every measurement; every
///         call is isolated (execution gas net of refunds, excluding the 21,000 base and
///         the calldata recorded next to it).
contract ProdV4Test is ProdCommon {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    IPoolManager constant MANAGER = IPoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);
    IUniversalRouter constant UR = IUniversalRouter(0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af);
    IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    int24 constant TICK_LOWER = -887220;
    int24 constant TICK_UPPER = 887220;
    int24 constant INIT_TICK = 30;

    // Universal Router command / v4 action bytes (universal-router Commands.sol, v4-periphery Actions.sol)
    bytes1 constant CMD_V4_SWAP = 0x10;
    uint8 constant ACT_SWAP_EXACT_IN_SINGLE = 0x06;
    uint8 constant ACT_SETTLE_ALL = 0x0c;
    uint8 constant ACT_TAKE_ALL = 0x0f;

    // IV4Router.ExactInputSingleParams as deployed in the 2025 Universal Router (no minHopPriceX36)
    struct ExactInputSingleParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountIn;
        uint128 amountOutMinimum;
        bytes hookData;
    }

    PoolKey keyAB;
    PoolKey keyBC;
    PoolKey keyCD;
    PoolKey keyNative;
    V4MinimalRouter minimal;
    PoolModifyLiquidityTest mintRouter;

    function _key(address c0, address c1) internal pure returns (PoolKey memory) {
        return PoolKey({currency0: Currency.wrap(c0), currency1: Currency.wrap(c1), fee: 3000, tickSpacing: 60, hooks: IHooks(address(0))});
    }

    function _setup() internal {
        assertEq(block.chainid, 1, "mainnet fork");
        assertGt(address(MANAGER).code.length, 0, "PoolManager deployed");
        assertGt(address(UR).code.length, 0, "Universal Router deployed");
        _deployTokens();

        mintRouter = new PoolModifyLiquidityTest(MANAGER);
        minimal = new V4MinimalRouter(MANAGER);
        address[4] memory ts = [TOKEN_A, TOKEN_B, TOKEN_C, TOKEN_D];
        for (uint256 i = 0; i < 4; i++) {
            IFreshToken(ts[i]).approve(address(mintRouter), type(uint256).max);
        }
        keyAB = _key(TOKEN_A, TOKEN_B);
        keyBC = _key(TOKEN_B, TOKEN_C);
        keyCD = _key(TOKEN_C, TOKEN_D);
        keyNative = _key(address(0), TOKEN_B);
        _init(keyAB, 0);
        _init(keyBC, 0);
        _init(keyCD, 0);
        _init(keyNative, LIQ_AMOUNT);

        IFreshToken(TOKEN_A).approve(address(minimal), type(uint256).max);
        IFreshToken(TOKEN_A).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(TOKEN_A, address(UR), type(uint160).max, uint48(block.timestamp + 1 days));
        assertEq(IFreshToken(TOKEN_A).allowance(address(this), address(minimal)), type(uint256).max, "max approval");
    }

    function _init(PoolKey memory key, uint256 value) internal {
        (uint160 sqrtPrice,,,) = MANAGER.getSlot0(key.toId());
        assertEq(sqrtPrice, 0, "pool must not exist yet");
        MANAGER.initialize(key, TickMath.getSqrtPriceAtTick(INIT_TICK));
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            TickMath.getSqrtPriceAtTick(INIT_TICK),
            TickMath.getSqrtPriceAtTick(TICK_LOWER),
            TickMath.getSqrtPriceAtTick(TICK_UPPER),
            LIQ_AMOUNT,
            LIQ_AMOUNT
        );
        mintRouter.modifyLiquidity{value: value}(
            key, ModifyLiquidityParams({tickLower: TICK_LOWER, tickUpper: TICK_UPPER, liquidityDelta: int256(uint256(liq)), salt: bytes32(0)}), ""
        );
        assertEq(MANAGER.getLiquidity(key.toId()), liq);
    }

    function _tick(PoolKey memory key) internal view returns (int24 tick) {
        (, tick,,) = MANAGER.getSlot0(key.toId());
    }

    function _call(string memory name, address to, uint256 value, bytes memory data, PoolKey memory lastPool, address tokenOut)
        internal
        returns (uint256 out)
    {
        int24 before = _tick(lastPool);
        uint256 balBefore = IFreshToken(tokenOut).balanceOf(address(this));
        assertGt(balBefore, 0, "recipient already holds the output token");
        (bool ok, bytes memory ret) = to.call{value: value}(data);
        if (bytes(name).length > 0) vm.snapshotGasLastCall(name);
        assertTrue(ok, "call reverted");
        out = IFreshToken(tokenOut).balanceOf(address(this)) - balBefore;
        if (ret.length == 32) assertEq(abi.decode(ret, (uint256)), out, "router-reported output equals balance change");
        int256 moved = int256(_tick(lastPool)) - int256(before);
        if (moved < 0) moved = -moved;
        assertLe(uint256(moved), 1, "moved more than one tick");
        if (bytes(name).length > 0) {
            vm.snapshotValue(string.concat(name, " | output (wei)"), out);
            vm.snapshotValue(string.concat(name, " | ticks moved"), uint256(moved));
        }
    }

    // ---- minimal single-lock router ----

    function _min(uint256 n, string memory name, address tokenIn, uint256 value, address tokenOut, uint256 minOut) internal {
        _setup();
        V4MinimalRouter.Hop[] memory hops = new V4MinimalRouter.Hop[](n);
        PoolKey memory last;
        if (tokenIn == address(0)) {
            hops[0] = V4MinimalRouter.Hop(keyNative, TickMath.MIN_SQRT_PRICE + 1);
            last = keyNative;
        } else {
            hops[0] = V4MinimalRouter.Hop(keyAB, TickMath.MIN_SQRT_PRICE + 1);
            if (n > 1) hops[1] = V4MinimalRouter.Hop(keyBC, TickMath.MIN_SQRT_PRICE + 1);
            if (n > 2) hops[2] = V4MinimalRouter.Hop(keyCD, TickMath.MIN_SQRT_PRICE + 1);
            last = hops[n - 1].key;
        }
        bytes memory data = abi.encodeCall(
            minimal.multiHop, (hops, Currency.wrap(tokenIn), Currency.wrap(tokenOut), -int256(SWAP_AMOUNT))
        );
        _call("", address(minimal), value, data, last, tokenOut);
        uint256 out = _call(name, address(minimal), value, data, last, tokenOut);
        assertGe(out, minOut, "output sanity");
        _recordCalldata(name, tokenIn == address(0) ? "v4-minimal-native" : string.concat("v4-minimal-", vm.toString(n), n == 1 ? "pool" : "pools"), data);
    }

    /// forge-config: default.isolate = true
    function test_prod_v4_minimal_1pool() public {
        _min(1, "prod v4 minimal locker 1 pool A->B", TOKEN_A, 0, TOKEN_B, 0.99e18);
    }

    /// forge-config: default.isolate = true
    function test_prod_v4_minimal_2pools() public {
        _min(2, "prod v4 minimal locker 2 pools A->B->C", TOKEN_A, 0, TOKEN_C, 0.98e18);
    }

    /// forge-config: default.isolate = true
    function test_prod_v4_minimal_3pools() public {
        _min(3, "prod v4 minimal locker 3 pools A->B->C->D", TOKEN_A, 0, TOKEN_D, 0.97e18);
    }

    /// forge-config: default.isolate = true
    function test_prod_v4_minimal_native() public {
        _min(1, "prod v4 minimal locker 1 pool ETH->B", address(0), SWAP_AMOUNT, TOKEN_B, 0.99e18);
    }

    // ---- production Universal Router, Permit2-funded ----

    /// forge-config: default.isolate = true
    function test_prod_v4_universalRouter_1pool() public {
        _setup();
        bytes memory actions = abi.encodePacked(ACT_SWAP_EXACT_IN_SINGLE, ACT_SETTLE_ALL, ACT_TAKE_ALL);
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            ExactInputSingleParams({poolKey: keyAB, zeroForOne: true, amountIn: uint128(SWAP_AMOUNT), amountOutMinimum: 0, hookData: ""})
        );
        params[1] = abi.encode(Currency.wrap(TOKEN_A), SWAP_AMOUNT);
        params[2] = abi.encode(Currency.wrap(TOKEN_B), uint256(0));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(actions, params);
        bytes memory data = abi.encodeCall(IUniversalRouter.execute, (abi.encodePacked(CMD_V4_SWAP), inputs, type(uint256).max));
        string memory name = "prod v4 Universal Router V4_SWAP 1 pool A->B (Permit2)";
        _call("", address(UR), 0, data, keyAB, TOKEN_B);
        uint256 out = _call(name, address(UR), 0, data, keyAB, TOKEN_B);
        assertGe(out, 0.99e18, "output sanity");
        assertLe(out, (SWAP_AMOUNT * 101) / 100, "output sanity"); // pools sit at tick 30.5, so 1 A buys ~1.003 B before the 0.3% fee
        _recordCalldata(name, "v4-universal-router-1pool", data);
    }
}
