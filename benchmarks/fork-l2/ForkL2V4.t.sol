// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {Test, Vm} from "forge-std/Test.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {SwapParams} from "v4-core/src/types/PoolOperation.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IUnlockCallback} from "v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {TransientStateLibrary} from "v4-core/src/libraries/TransientStateLibrary.sol";
import {CurrencySettler} from "v4-core/test/utils/CurrencySettler.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IStateViewLike {
    function getSlot0(PoolId poolId)
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee);
    function getLiquidity(PoolId poolId) external view returns (uint128 liquidity);
}

/// @notice Minimal single-lock exact-input swapper over a live v4 pool (same contract as the
///         mainnet fork harness). The production Universal Router would cost more on top.
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

/// @notice L2-fork measurement: the deployed v4 PoolManager + the deepest live WETH/USDC pool
///         (hooks = address(0)) through the minimal locker above, USDC exact-input to WETH,
///         warmed with one identical unmeasured swap; every call isolated, snapshot =
///         execution gas of the measured call (net of refunds, excluding the 21,000 base and
///         calldata). Ticks are read from StateView and cross-checked against the `Swap` event.
abstract contract ForkL2V4Base is Test {
    using PoolIdLibrary for PoolKey;

    bytes32 constant SWAP_TOPIC = keccak256("Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)");

    struct Cfg {
        string name;
        uint256 chainId;
        uint256 blockNumber;
        uint256 timestamp;
        address manager;
        address stateView;
        address weth;
        address usdc;
        uint24 fee;
        int24 spacing;
        bytes32 expectedPoolId;
    }

    ForkSwapRouter internal router;
    PoolKey internal key;
    PoolId internal poolId;

    function _cfg() internal pure virtual returns (Cfg memory);

    function _setup() internal {
        Cfg memory c = _cfg();
        assertEq(block.chainid, c.chainId, "chain id");
        // Arbitrum forks report the L1 block number as `block.number`; the timestamp pins the block on both chains.
        assertEq(block.timestamp, c.timestamp, "pinned block timestamp");
        assertGt(c.manager.code.length, 0, "PoolManager deployed");
        router = new ForkSwapRouter(IPoolManager(c.manager));
        // WETH < USDC on both chains: USDC is currency1, so USDC->WETH is oneForZero
        key = PoolKey({
            currency0: Currency.wrap(c.weth),
            currency1: Currency.wrap(c.usdc),
            fee: c.fee,
            tickSpacing: c.spacing,
            hooks: IHooks(address(0))
        });
        poolId = key.toId();
        assertEq(PoolId.unwrap(poolId), c.expectedPoolId, "pool id");
        (uint160 sqrtPriceX96,,, uint24 lpFee) = IStateViewLike(c.stateView).getSlot0(poolId);
        assertGt(sqrtPriceX96, 0, "pool initialized (no hook)");
        assertEq(lpFee, c.fee);
        vm.snapshotValue(string.concat("fork-l2 ", c.name, " v4 pool liquidity"), IStateViewLike(c.stateView).getLiquidity(poolId));
        deal(c.usdc, address(this), 1_000_000_000_000); // 1e6 USDC
        IERC20Like(c.usdc).approve(address(router), type(uint256).max);
        assertEq(IERC20Like(c.usdc).allowance(address(this), address(router)), type(uint256).max, "max approval");
    }

    function _calldata(int256 amountIn) internal view returns (bytes memory) {
        return abi.encodeCall(router.swap, (key, false, amountIn, TickMath.MAX_SQRT_PRICE - 1, address(this)));
    }

    function _swap(int256 amountIn, string memory snapshotName) internal returns (uint256 out, bytes memory cd) {
        Cfg memory c = _cfg();
        cd = _calldata(amountIn);
        (, int24 tickBefore,,) = IStateViewLike(c.stateView).getSlot0(poolId);
        uint256 wethBefore = IERC20Like(c.weth).balanceOf(address(this));
        vm.recordLogs();
        (bool ok, bytes memory ret) = address(router).call(cd);
        if (bytes(snapshotName).length > 0) vm.snapshotGasLastCall(snapshotName);
        assertTrue(ok, "swap");
        out = abi.decode(ret, (uint256));
        assertEq(IERC20Like(c.weth).balanceOf(address(this)) - wethBefore, out, "output delivered");
        (, int24 tickAfter,,) = IStateViewLike(c.stateView).getSlot0(poolId);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool seen;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == c.manager && logs[i].topics.length > 0 && logs[i].topics[0] == SWAP_TOPIC) {
                assertEq(logs[i].topics[1], PoolId.unwrap(poolId), "Swap event for this pool");
                (,,,, int24 eventTick,) = abi.decode(logs[i].data, (int128, int128, uint160, uint128, int24, uint24));
                assertEq(eventTick, tickAfter, "Swap event tick equals StateView tick");
                seen = true;
            }
        }
        assertTrue(seen, "Swap event found");
        if (bytes(snapshotName).length > 0) {
            emit log_named_int("v4 tick before", tickBefore);
            emit log_named_int("v4 tick after", tickAfter);
            int256 moved = int256(tickAfter) - int256(tickBefore);
            vm.snapshotValue(string.concat(snapshotName, " | ticks moved"), uint256(moved < 0 ? -moved : moved));
        }
    }

    function _run(uint256 usdc, uint256 minOut, uint256 maxOut) internal {
        _setup();
        Cfg memory c = _cfg();
        _swap(-int256(usdc), ""); // warm-up, unmeasured
        assertGt(IERC20Like(c.weth).balanceOf(address(this)), 0, "recipient WETH balance nonzero before measured swap");
        string memory size = vm.toString(usdc / 1_000_000);
        string memory name = string.concat(
            "fork-l2 ", c.name, " v4 PoolManager minimal locker ", size, " USDC->WETH fee-", vm.toString(uint256(c.fee))
        );
        (uint256 out, bytes memory cd) = _swap(-int256(usdc), name);
        vm.snapshotValue(string.concat("fork-l2 ", c.name, " v4 output ", size, " USDC->WETH (wei)"), out);
        vm.snapshotValue(string.concat("fork-l2 ", c.name, " v4 calldata bytes ", size, " USDC"), cd.length);
        vm.writeFile(string.concat("calldata/v4-minimal-locker-", c.name, "-", size, ".hex"), vm.toString(cd));
        emit log_named_uint("v4 measured output (WETH wei)", out);
        assertGe(out, minOut);
        assertLe(out, maxOut);
    }

    /// forge-config: default.isolate = true
    function test_fork_l2_v4_minimalLocker_1000() public {
        _run(1_000_000_000, 0.38 ether, 0.43 ether);
    }

    /// forge-config: default.isolate = true
    function test_fork_l2_v4_minimalLocker_100() public {
        _run(100_000_000, 0.038 ether, 0.043 ether);
    }

    /// forge-config: default.isolate = true
    function test_fork_l2_v4_minimalLocker_50() public {
        _run(50_000_000, 0.019 ether, 0.0215 ether);
    }
}

/// Run with: --fork-url <base-archive-rpc> --fork-block-number 51439900
contract ForkL2V4BaseTest is ForkL2V4Base {
    function _cfg() internal pure override returns (Cfg memory) {
        return Cfg({
            name: "base",
            chainId: 8453,
            blockNumber: 51439900,
            timestamp: 1789669147,
            manager: 0x498581fF718922c3f8e6A244956aF099B2652b2b, // docs.uniswap.org v4 deployments, Base
            stateView: 0xA3c0c9b65baD0b08107Aa264b0f3dB444b867A71,
            weth: 0x4200000000000000000000000000000000000006,
            usdc: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
            fee: 3000, // deepest WETH/USDC (hookless) tier of 100/500/3000/10000
            spacing: 60,
            expectedPoolId: 0x1d8c55f347727c0fb4f5e1b65cdb93639e0c7102580a7d345e1144cd5a718f54
        });
    }
}

/// Run with: --fork-url <arbitrum-archive-rpc> --fork-block-number 506178800
contract ForkL2V4ArbitrumTest is ForkL2V4Base {
    function _cfg() internal pure override returns (Cfg memory) {
        return Cfg({
            name: "arbitrum",
            chainId: 42161,
            blockNumber: 506178800,
            timestamp: 1789669181,
            manager: 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32, // docs.uniswap.org v4 deployments, Arbitrum One
            stateView: 0x76Fd297e2D437cd7f76d50F01AfE6160f86e9990,
            weth: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            usdc: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            fee: 500, // deepest WETH/USDC (hookless) tier of 100/500/3000/10000
            spacing: 10,
            expectedPoolId: 0xfc7b3ad139daaf1e9c3637ed921c154d1b04286f8a82b805a6c352da57028653
        });
    }
}
