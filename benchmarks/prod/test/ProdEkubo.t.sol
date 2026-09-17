// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.33;

import {Vm} from "forge-std/Test.sol";
import {ProdCommon, IFreshToken} from "./ProdCommon.sol";
import {ICore} from "ekubo/src/interfaces/ICore.sol";
import {PoolKey, toPoolId} from "ekubo/src/types/poolKey.sol";
import {PoolId} from "ekubo/src/types/poolId.sol";
import {PoolConfig, createConcentratedPoolConfig} from "ekubo/src/types/poolConfig.sol";
import {PoolState} from "ekubo/src/types/poolState.sol";
import {SqrtRatio, MIN_SQRT_RATIO, MAX_SQRT_RATIO} from "ekubo/src/types/sqrtRatio.sol";
import {NATIVE_TOKEN_ADDRESS} from "ekubo/src/math/constants.sol";
import {SwapParameters, createSwapParameters} from "ekubo/src/types/swapParameters.sol";
import {PoolBalanceUpdate} from "ekubo/src/types/poolBalanceUpdate.sol";
import {BaseLocker} from "ekubo/src/base/BaseLocker.sol";
import {FlashAccountantLib} from "ekubo/src/libraries/FlashAccountantLib.sol";
import {CoreLib} from "ekubo/src/libraries/CoreLib.sol";

interface IPositionsLike {
    function name() external view returns (string memory);
    function mintAndDepositWithSalt(
        bytes32 salt,
        PoolKey memory poolKey,
        int32 tickLower,
        int32 tickUpper,
        uint128 maxAmount0,
        uint128 maxAmount1,
        uint128 minLiquidity
    ) external payable returns (uint256 id, uint128 liquidity, uint128 amount0, uint128 amount1);
}

/// @notice True-minimal single-lock exact-input locker over the production Core, the same
///         shape as the v4 minimal locker: lock, swap each hop, pay the input once, withdraw
///         the output once (net settlement). Native input rides on msg.value.
contract MinimalEkuboRouter is BaseLocker {
    using FlashAccountantLib for *;
    using CoreLib for ICore;

    constructor(ICore core) BaseLocker(core) {}

    function swapExactIn(PoolKey[] memory keys, address tokenIn, int128 amountIn, address payer)
        external
        payable
        returns (int128 amountOut)
    {
        amountOut = abi.decode(lock(abi.encode(keys, tokenIn, amountIn, payer, msg.sender, msg.value)), (int128));
    }

    function handleLockData(uint256, bytes memory data) internal override returns (bytes memory result) {
        (PoolKey[] memory keys, address tokenIn, int128 amount, address payer, address recipient, uint256 value) =
            abi.decode(data, (PoolKey[], address, int128, address, address, uint256));
        ICore core = ICore(payable(address(ACCOUNTANT)));
        address firstToken = tokenIn;
        int128 firstAmount = amount;
        for (uint256 i = 0; i < keys.length; i++) {
            bool isToken1 = tokenIn == keys[i].token1;
            require(isToken1 || tokenIn == keys[i].token0, "hop token");
            SwapParameters params =
                createSwapParameters(isToken1 ? MAX_SQRT_RATIO : MIN_SQRT_RATIO, amount, isToken1, 0);
            (PoolBalanceUpdate bu,) = core.swap(i == 0 ? value : 0, keys[i], params);
            if (isToken1) {
                require(bu.delta1() == amount && bu.delta0() < 0, "hop");
                amount = -bu.delta0();
                tokenIn = keys[i].token0;
            } else {
                require(bu.delta0() == amount && bu.delta1() < 0, "hop");
                amount = -bu.delta1();
                tokenIn = keys[i].token1;
            }
        }
        if (firstToken != NATIVE_TOKEN_ADDRESS) ACCOUNTANT.payFrom(payer, firstToken, uint128(firstAmount));
        ACCOUNTANT.withdraw(tokenIn, recipient, uint128(amount));
        result = abi.encode(amount);
    }
}

/// @notice Production Ekubo contracts on a fork of the latest mainnet block, fresh tokens:
///         Core (all pools), Positions (capitalizes the pools in setup, unmeasured) and the
///         deployed Yul router with SDK-generated calldata (`encode-prod-routes.mjs`). The
///         minimal locker above is the like-for-like counterpart of the v3/v4 minimal
///         routers. One identical unmeasured call precedes every measurement; every call is
///         isolated, so the snapshot is the execution gas of the measured call net of
///         refunds, excluding the 21,000 base and the calldata recorded next to it.
contract ProdEkuboTest is ProdCommon {
    using CoreLib for ICore;

    ICore constant CORE = ICore(payable(0x00000000000014aA86C5d3c41765bb24e11bd701));
    IPositionsLike constant POSITIONS = IPositionsLike(0x02D9876A21AF7545f8632C3af76eC90b5ad4b66D);
    address constant YUL_ROUTER = 0x7B2aA7Ecc0B5936b7C52E6259A19C3BA557d0748;
    address constant RECIPIENT = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496; // this test contract, embedded in the routes

    uint64 constant FEE_0_3 = 55340232221128654; // floor(0.003 * 2^64), the Uniswap 3000 tier
    uint32 constant TICK_SPACING = 6000; // Uniswap spacing 60, Ekubo ticks are 100x finer
    int32 constant RANGE_LOWER = -88722000;
    int32 constant RANGE_UPPER = 88722000;
    int32 constant INIT_TICK = 3050; // strictly inside a tick (Uniswap tick 30.5), never on a spacing multiple
    bytes32 constant CONFIG = 0x000000000000000000000000000000000000000000c49ba5e353f7ce80001770;

    PoolKey keyAB;
    PoolKey keyBC;
    PoolKey keyCD;
    PoolKey keyNative;
    MinimalEkuboRouter minimal;

    function _key(address t0, address t1) internal pure returns (PoolKey memory k) {
        k = PoolKey({token0: t0, token1: t1, config: createConcentratedPoolConfig(FEE_0_3, TICK_SPACING, address(0))});
        require(PoolConfig.unwrap(k.config) == CONFIG, "config word differs from the one in the SDK routes");
    }

    function _setup() internal {
        assertEq(block.chainid, 1, "mainnet fork");
        assertEq(address(this), RECIPIENT, "route recipient is this contract");
        assertGt(address(CORE).code.length, 0, "Core deployed");
        assertGt(YUL_ROUTER.code.length, 0, "Yul router deployed");
        assertEq(POSITIONS.name(), "Ekubo Positions", "production Positions");
        _deployTokens();

        keyAB = _key(TOKEN_A, TOKEN_B);
        keyBC = _key(TOKEN_B, TOKEN_C);
        keyCD = _key(TOKEN_C, TOKEN_D);
        keyNative = _key(NATIVE_TOKEN_ADDRESS, TOKEN_B);
        PoolKey[4] memory keys = [keyAB, keyBC, keyCD, keyNative];
        for (uint256 i = 0; i < 4; i++) {
            assertFalse(CORE.poolState(toPoolId(keys[i])).isInitialized(), "pool must not exist yet");
            CORE.initializePool(keys[i], INIT_TICK);
        }
        address[4] memory ts = [TOKEN_A, TOKEN_B, TOKEN_C, TOKEN_D];
        for (uint256 i = 0; i < 4; i++) {
            IFreshToken(ts[i]).approve(address(POSITIONS), type(uint256).max);
        }
        // Capitalize through the production Positions manager (unmeasured): one full-range
        // position per pool, 1M tokens a side, so no measured swap crosses an initialized tick.
        // Explicit salts: the deployed manager's `mintAndDeposit` derives its salt from
        // prevrandao and remaining gas, which back-to-back mints in one context share.
        for (uint256 i = 0; i < 3; i++) {
            (, uint128 liq,,) = POSITIONS.mintAndDepositWithSalt(
                bytes32(i + 1), keys[i], RANGE_LOWER, RANGE_UPPER, uint128(LIQ_AMOUNT), uint128(LIQ_AMOUNT), 0
            );
            assertGt(liq, 0);
        }
        POSITIONS.mintAndDepositWithSalt{value: LIQ_AMOUNT}(
            bytes32(uint256(4)), keyNative, RANGE_LOWER, RANGE_UPPER, uint128(LIQ_AMOUNT), uint128(LIQ_AMOUNT), 0
        );

        minimal = new MinimalEkuboRouter(CORE);
        IFreshToken(TOKEN_A).approve(YUL_ROUTER, type(uint256).max);
        IFreshToken(TOKEN_A).approve(address(minimal), type(uint256).max);
        assertEq(IFreshToken(TOKEN_A).allowance(address(this), YUL_ROUTER), type(uint256).max, "max approval");
    }

    function _tick(PoolKey memory k) internal view returns (int32 tick) {
        (, tick,) = CORE.poolState(toPoolId(k)).parse();
    }

    /// @dev Calls `to` with `data` (and `value`), snapshots the call when `name` is set, and
    ///      checks the swap moved the last pool by at most one Uniswap tick (100 fine ticks).
    function _call(string memory name, address to, uint256 value, bytes memory data, PoolKey memory lastPool, address tokenOut)
        internal
        returns (uint256 out, bytes memory ret)
    {
        int32 before = _tick(lastPool);
        uint256 balBefore = IFreshToken(tokenOut).balanceOf(address(this));
        assertGt(balBefore, 0, "recipient already holds the output token (nonzero -> nonzero balance write)");
        bool ok;
        (ok, ret) = to.call{value: value}(data);
        if (bytes(name).length > 0) vm.snapshotGasLastCall(name);
        assertTrue(ok, "call reverted");
        out = IFreshToken(tokenOut).balanceOf(address(this)) - balBefore;
        int256 moved = int256(_tick(lastPool)) - int256(before);
        if (moved < 0) moved = -moved;
        assertLe(uint256(moved), 100, "moved more than one Uniswap tick");
        if (bytes(name).length > 0) {
            vm.snapshotValue(string.concat(name, " | output (wei)"), out);
            vm.snapshotValue(string.concat(name, " | fine ticks moved"), uint256(moved));
        }
    }

    function _route(string memory file) internal view returns (bytes memory) {
        return vm.parseBytes(vm.readFile(string.concat("calldata/", file, ".hex")));
    }

    // ---- production Yul router, SDK calldata ----

    function _lastPool(uint256 n) internal view returns (PoolKey memory) {
        // resolved after _setup(): the keys are storage, so they must not be read before it
        return n == 0 ? keyNative : (n == 1 ? keyAB : (n == 2 ? keyBC : keyCD));
    }

    function _yul(string memory file, string memory name, uint256 value, uint256 n, address tokenOut, uint256 minOut) internal {
        _setup();
        PoolKey memory lastPool = _lastPool(n);
        bytes memory route = _route(file);
        _call("", YUL_ROUTER, value, route, lastPool, tokenOut); // warm-up, unmeasured
        (uint256 out, bytes memory ret) = _call(name, YUL_ROUTER, value, route, lastPool, tokenOut);
        (,, int256 specified, int256 calculated) = abi.decode(ret, (address, address, int256, int256));
        assertEq(uint256(specified), SWAP_AMOUNT, "exact input");
        assertEq(uint256(calculated), out, "router-reported output equals balance change");
        assertGe(out, minOut, "output sanity");
        assertLe(out, (SWAP_AMOUNT * 101) / 100, "output sanity"); // pools sit at tick 30.5, so 1 A buys ~1.003 B before the 0.3% fee
        _recordCalldata(name, file, route);
    }

    /// forge-config: default.isolate = true
    function test_prod_ekubo_yul_1pool() public {
        _yul("ekubo-yul-1pool", "prod ekubo Yul router 1 pool A->B", 0, 1, TOKEN_B, 0.99e18);
    }

    /// forge-config: default.isolate = true
    function test_prod_ekubo_yul_2pools() public {
        _yul("ekubo-yul-2pools", "prod ekubo Yul router 2 pools A->B->C", 0, 2, TOKEN_C, 0.98e18);
    }

    /// forge-config: default.isolate = true
    function test_prod_ekubo_yul_3pools() public {
        _yul("ekubo-yul-3pools", "prod ekubo Yul router 3 pools A->B->C->D", 0, 3, TOKEN_D, 0.97e18);
    }

    /// forge-config: default.isolate = true
    function test_prod_ekubo_yul_native() public {
        _yul("ekubo-yul-native", "prod ekubo Yul router 1 pool ETH->B", SWAP_AMOUNT, 0, TOKEN_B, 0.99e18);
    }

    // ---- minimal single-lock locker (like-for-like with the v4 minimal locker) ----

    function _min(uint256 n, string memory name, address tokenIn, uint256 value, address tokenOut, uint256 minOut) internal {
        _setup();
        PoolKey[] memory keys = new PoolKey[](n);
        PoolKey memory last;
        if (tokenIn == NATIVE_TOKEN_ADDRESS) {
            keys[0] = keyNative;
            last = keyNative;
        } else {
            keys[0] = keyAB;
            if (n > 1) keys[1] = keyBC;
            if (n > 2) keys[2] = keyCD;
            last = keys[n - 1];
        }
        bytes memory data = abi.encodeCall(minimal.swapExactIn, (keys, tokenIn, int128(int256(SWAP_AMOUNT)), address(this)));
        _call("", address(minimal), value, data, last, tokenOut);
        (uint256 out,) = _call(name, address(minimal), value, data, last, tokenOut);
        assertGe(out, minOut, "output sanity");
        _recordCalldata(name, tokenIn == NATIVE_TOKEN_ADDRESS ? "ekubo-minimal-native" : string.concat("ekubo-minimal-", vm.toString(n), n == 1 ? "pool" : "pools"), data);
    }

    /// forge-config: default.isolate = true
    function test_prod_ekubo_minimal_1pool() public {
        _min(1, "prod ekubo minimal locker 1 pool A->B", TOKEN_A, 0, TOKEN_B, 0.99e18);
    }

    /// forge-config: default.isolate = true
    function test_prod_ekubo_minimal_2pools() public {
        _min(2, "prod ekubo minimal locker 2 pools A->B->C", TOKEN_A, 0, TOKEN_C, 0.98e18);
    }

    /// forge-config: default.isolate = true
    function test_prod_ekubo_minimal_3pools() public {
        _min(3, "prod ekubo minimal locker 3 pools A->B->C->D", TOKEN_A, 0, TOKEN_D, 0.97e18);
    }

    /// forge-config: default.isolate = true
    function test_prod_ekubo_minimal_native() public {
        _min(1, "prod ekubo minimal locker 1 pool ETH->B", NATIVE_TOKEN_ADDRESS, SWAP_AMOUNT, TOKEN_B, 0.99e18);
    }
}
