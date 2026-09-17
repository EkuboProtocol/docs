// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.33;

import {Test, Vm} from "forge-std/Test.sol";
import {ICore} from "ekubo/src/interfaces/ICore.sol";
import {PoolKey, toPoolId} from "ekubo/src/types/poolKey.sol";
import {PoolId} from "ekubo/src/types/poolId.sol";
import {PoolConfig, createConcentratedPoolConfig} from "ekubo/src/types/poolConfig.sol";
import {PoolState} from "ekubo/src/types/poolState.sol";
import {SqrtRatio} from "ekubo/src/types/sqrtRatio.sol";
import {createPositionId} from "ekubo/src/types/positionId.sol";
import {PoolBalanceUpdate} from "ekubo/src/types/poolBalanceUpdate.sol";
import {BaseLocker} from "ekubo/src/base/BaseLocker.sol";
import {FlashAccountantLib} from "ekubo/src/libraries/FlashAccountantLib.sol";
import {CoreLib} from "ekubo/src/libraries/CoreLib.sol";

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

/// @notice Bare core-level liquidity provision used only to capitalize the fresh pool in
///         setup (lock, updatePosition, settle net). Never measured.
contract BareMintRouter is BaseLocker {
    using FlashAccountantLib for *;

    constructor(ICore core) BaseLocker(core) {}

    function mint(PoolKey memory key, bytes24 salt, int32 tickLower, int32 tickUpper, int128 liquidityDelta, address payer)
        external
        returns (PoolBalanceUpdate balanceUpdate)
    {
        balanceUpdate = abi.decode(
            lock(abi.encode(key, salt, tickLower, tickUpper, liquidityDelta, payer, msg.sender)), (PoolBalanceUpdate)
        );
    }

    function handleLockData(uint256, bytes memory data) internal override returns (bytes memory result) {
        (
            PoolKey memory key,
            bytes24 salt,
            int32 tickLower,
            int32 tickUpper,
            int128 liquidityDelta,
            address payer,
            address recipient
        ) = abi.decode(data, (PoolKey, bytes24, int32, int32, int128, address, address));
        PoolBalanceUpdate balanceUpdate = ICore(payable(address(ACCOUNTANT))).updatePosition(
            key, createPositionId(salt, tickLower, tickUpper), liquidityDelta
        );
        if (balanceUpdate.delta0() > 0) {
            ACCOUNTANT.payFrom(payer, key.token0, uint128(balanceUpdate.delta0()));
        } else if (balanceUpdate.delta0() < 0) {
            ACCOUNTANT.withdraw(key.token0, recipient, uint128(-balanceUpdate.delta0()));
        }
        if (balanceUpdate.delta1() > 0) {
            ACCOUNTANT.payFrom(payer, key.token1, uint128(balanceUpdate.delta1()));
        } else if (balanceUpdate.delta1() < 0) {
            ACCOUNTANT.withdraw(key.token1, recipient, uint128(-balanceUpdate.delta1()));
        }
        result = abi.encode(balanceUpdate);
    }
}

/// @notice L2-fork measurement of the production Ekubo Yul router on Base / Arbitrum One.
///         No live Ekubo WETH/USDC (or USDC/USDT) pool on either chain can absorb the swap
///         at the pinned block (see benchmarks/README.md), so the pool is created fresh on
///         the fork at the deepest Uniswap v3 pool's price, fee tier and (100x finer)
///         tick spacing, and capitalized with exactly that pool's active liquidity through
///         a bare locker in setup. The measured call is the real deployed Yul router with
///         SDK-generated calldata (`encode-l2-routes.mjs`), USDC exact-input to WETH,
///         warmed with one identical unmeasured swap; every call is isolated so the snapshot
///         is the execution gas of the measured swap (net of refunds, excluding the 21,000
///         base and calldata).
abstract contract ForkL2EkuboBase is Test {
    using CoreLib for ICore;

    struct Cfg {
        string name;
        uint256 chainId;
        uint256 blockNumber;
        uint256 timestamp;
        address weth;
        address usdc;
        uint64 fee;
        uint32 spacing;
        int32 initTick;
        int32 lower;
        int32 upper;
        uint128 liquidity;
        bytes32 config;
    }

    ICore constant CORE = ICore(payable(0x00000000000014aA86C5d3c41765bb24e11bd701));
    address constant YUL_ROUTER = 0x7B2aA7Ecc0B5936b7C52E6259A19C3BA557d0748;
    address constant RECIPIENT = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;

    PoolKey internal key;
    PoolId internal poolId;
    BareMintRouter internal minter;

    function _cfg() internal pure virtual returns (Cfg memory);
    function _route(uint256 usdc) internal pure virtual returns (bytes memory);

    function _setup() internal {
        Cfg memory c = _cfg();
        assertEq(block.chainid, c.chainId, "chain id");
        // Arbitrum forks report the L1 block number as `block.number`; the timestamp pins the block on both chains.
        assertEq(block.timestamp, c.timestamp, "pinned block timestamp");
        assertEq(address(this), RECIPIENT, "route recipient is this contract");
        assertGt(address(CORE).code.length, 0, "Core deployed");
        assertGt(YUL_ROUTER.code.length, 0, "Yul router deployed");

        key = PoolKey({token0: c.weth, token1: c.usdc, config: createConcentratedPoolConfig(c.fee, c.spacing, address(0))});
        assertEq(PoolConfig.unwrap(key.config), c.config, "config word equals the one encoded into the SDK route");
        poolId = toPoolId(key);
        assertFalse(CORE.poolState(poolId).isInitialized(), "pool does not exist yet on this chain");
        CORE.initializePool(key, c.initTick);

        minter = new BareMintRouter(CORE);
        deal(c.weth, address(this), 100_000 ether);
        deal(c.usdc, address(this), 1_000_000_000_000_000); // 1e9 USDC
        IERC20Like(c.weth).approve(address(minter), type(uint256).max);
        IERC20Like(c.usdc).approve(address(minter), type(uint256).max);
        PoolBalanceUpdate u = minter.mint(key, bytes24(0), c.lower, c.upper, int128(c.liquidity), address(this));
        emit log_named_int("mint amount0 (WETH wei)", u.delta0());
        emit log_named_int("mint amount1 (USDC units)", u.delta1());
        (, int32 tick, uint128 liq) = CORE.poolState(poolId).parse();
        assertEq(liq, c.liquidity, "active liquidity equals the v3 pool's");
        assertEq(tick, c.initTick, "pool at init tick");
        assertGt(IERC20Like(c.weth).balanceOf(address(CORE)), 0, "Core holds WETH");
        assertGt(IERC20Like(c.usdc).balanceOf(address(CORE)), 0, "Core holds USDC");

        IERC20Like(c.usdc).approve(YUL_ROUTER, type(uint256).max);
        assertEq(IERC20Like(c.usdc).allowance(address(this), YUL_ROUTER), type(uint256).max, "max approval");
    }

    function _swap(bytes memory route, string memory snapshotName) internal returns (uint256 out) {
        Cfg memory c = _cfg();
        (, int32 tickBefore,) = CORE.poolState(poolId).parse();
        uint256 wethBefore = IERC20Like(c.weth).balanceOf(address(this));
        uint256 usdcBefore = IERC20Like(c.usdc).balanceOf(address(this));
        vm.recordLogs();
        (bool ok, bytes memory ret) = YUL_ROUTER.call(route);
        if (bytes(snapshotName).length > 0) vm.snapshotGasLastCall(snapshotName);
        assertTrue(ok, "swap");
        (address specifiedToken, address calculatedToken, int256 specified, int256 calculated) =
            abi.decode(ret, (address, address, int256, int256));
        assertEq(specifiedToken, c.usdc);
        assertEq(calculatedToken, c.weth);
        assertGt(calculated, 0);
        out = IERC20Like(c.weth).balanceOf(address(this)) - wethBefore;
        assertEq(out, uint256(calculated), "output equals router-reported calculated amount");
        assertEq(usdcBefore - IERC20Like(c.usdc).balanceOf(address(this)), uint256(specified), "input pulled");
        (, int32 tickAfter,) = CORE.poolState(poolId).parse();
        // Core's swap record: log0 with 116 bytes (locker, poolId, balanceUpdate, stateAfter)
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool seen;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == address(CORE) && logs[i].topics.length == 0 && logs[i].data.length == 116) {
                bytes memory d = logs[i].data;
                bytes32 stateAfter;
                assembly ("memory-safe") {
                    stateAfter := mload(add(d, 116))
                }
                (, int32 eventTick,) = PoolState.wrap(stateAfter).parse();
                assertEq(eventTick, tickAfter, "swap log stateAfter tick equals pool tick");
                seen = true;
            }
        }
        assertTrue(seen, "Core swap record found");
        if (bytes(snapshotName).length > 0) {
            emit log_named_int("ekubo tick before", tickBefore);
            emit log_named_int("ekubo tick after", tickAfter);
            int256 moved = int256(tickAfter) - int256(tickBefore);
            vm.snapshotValue(
                string.concat(snapshotName, " | Ekubo fine ticks moved (1/100 of a Uniswap tick)"),
                uint256(moved < 0 ? -moved : moved)
            );
            // no initialized tick between the position bounds: the swap must stay inside them
            assertGt(tickAfter, c.lower);
            assertLt(tickAfter, c.upper);
        }
    }

    function _run(uint256 usdc, uint256 minOut, uint256 maxOut) internal {
        _setup();
        bytes memory route = _route(usdc);
        _swap(route, ""); // warm-up: steady state, unmeasured
        Cfg memory c = _cfg();
        assertGt(IERC20Like(c.weth).balanceOf(address(this)), 0, "recipient WETH balance nonzero before measured swap");
        string memory size = vm.toString(usdc / 1_000_000);
        string memory name = string.concat("fork-l2 ", c.name, " ekubo Yul router ", size, " USDC->WETH fresh pool");
        uint256 out = _swap(route, name);
        vm.snapshotValue(string.concat("fork-l2 ", c.name, " ekubo output ", size, " USDC->WETH (wei)"), out);
        vm.snapshotValue(string.concat("fork-l2 ", c.name, " ekubo calldata bytes ", size, " USDC"), route.length);
        vm.writeFile(string.concat("calldata/ekubo-yul-", c.name, "-", size, ".hex"), vm.toString(route));
        emit log_named_uint("ekubo measured output (WETH wei)", out);
        assertGe(out, minOut);
        assertLe(out, maxOut);
    }

    /// forge-config: default.isolate = true
    function test_fork_l2_ekubo_yulRouter_1000() public {
        _run(1_000_000_000, 0.38 ether, 0.43 ether);
    }

    /// forge-config: default.isolate = true
    function test_fork_l2_ekubo_yulRouter_100() public {
        _run(100_000_000, 0.038 ether, 0.043 ether);
    }

    /// forge-config: default.isolate = true
    function test_fork_l2_ekubo_yulRouter_50() public {
        _run(50_000_000, 0.019 ether, 0.0215 ether);
    }
}

/// Run with: --fork-url <base-archive-rpc> --fork-block-number 51439900
contract ForkL2EkuboBaseTest is ForkL2EkuboBase {
    function _cfg() internal pure override returns (Cfg memory) {
        return Cfg({
            name: "base",
            chainId: 8453,
            blockNumber: 51439900,
            timestamp: 1789669147,
            weth: 0x4200000000000000000000000000000000000006,
            usdc: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
            fee: 55340232221128654, // floor(0.003 * 2^64): 0.3%, the deepest v3 WETH/USDC tier on Base
            spacing: 6000, // v3 spacing 60 x 100
            initTick: -19821136, // floor(ln(price) / ln(1.000001)) of the v3 fee-3000 pool's sqrtPriceX96
            lower: -19884000,
            upper: -19758000,
            liquidity: 37026042371903555946, // v3 fee-3000 pool `liquidity()` at the pinned block
            config: 0x000000000000000000000000000000000000000000c49ba5e353f7ce80001770
        });
    }

    function _route(uint256 usdc) internal pure override returns (bytes memory) {
        if (usdc == 1_000_000_000) {
            return
            hex"0100833589fCD6eDb6E08f4c7C32D4f71b54bdA029134200000000000000000000000000000000000006000000000000000005113442e2ec20b97FA9385bE102ac3EAc297483Dd6233D62b3e14960000000000000000000000003b9aca0000004200000000000000000000000000000000000006833589fCD6eDb6E08f4c7C32D4f71b54bdA02913000000000000000000000000000000000000000000c49ba5e353f7ce8000177000000000000000000000000000000000";
        }
        if (usdc == 100_000_000) {
            return
            hex"0100833589fCD6eDb6E08f4c7C32D4f71b54bdA02913420000000000000000000000000000000000000600000000000000000081b86d16b1367a7FA9385bE102ac3EAc297483Dd6233D62b3e149600000000000000000000000005f5e10000004200000000000000000000000000000000000006833589fCD6eDb6E08f4c7C32D4f71b54bdA02913000000000000000000000000000000000000000000c49ba5e353f7ce8000177000000000000000000000000000000000";
        }
        return
        hex"0100833589fCD6eDb6E08f4c7C32D4f71b54bdA02913420000000000000000000000000000000000000600000000000000000040dc368b589b3d7FA9385bE102ac3EAc297483Dd6233D62b3e149600000000000000000000000002faf08000004200000000000000000000000000000000000006833589fCD6eDb6E08f4c7C32D4f71b54bdA02913000000000000000000000000000000000000000000c49ba5e353f7ce8000177000000000000000000000000000000000";
    }
}

/// Run with: --fork-url <arbitrum-archive-rpc> --fork-block-number 506178800
contract ForkL2EkuboArbitrumTest is ForkL2EkuboBase {
    function _cfg() internal pure override returns (Cfg memory) {
        return Cfg({
            name: "arbitrum",
            chainId: 42161,
            blockNumber: 506178800,
            timestamp: 1789669181,
            weth: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            usdc: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            fee: 9223372036854775, // floor(0.0005 * 2^64): 0.05%, the deepest v3 WETH/USDC tier on Arbitrum
            spacing: 1000, // v3 spacing 10 x 100
            initTick: -19822971,
            lower: -19883000,
            upper: -19762000,
            liquidity: 3696581650313474097, // v3 fee-500 pool `liquidity()` at the pinned block
            config: 0x00000000000000000000000000000000000000000020c49ba5e353f7800003e8
        });
    }

    function _route(uint256 usdc) internal pure override returns (bytes memory) {
        if (usdc == 1_000_000_000) {
            return
            hex"0100af88d065e77c8cC2239327C5EDb3A432268e583182aF49447D8a07e3bd95BD0d56f35241523fBab100000000000000000513960a07707c937FA9385bE102ac3EAc297483Dd6233D62b3e14960000000000000000000000003b9aca00000082aF49447D8a07e3bd95BD0d56f35241523fBab1af88d065e77c8cC2239327C5EDb3A432268e583100000000000000000000000000000000000000000020c49ba5e353f7800003e800000000000000000000000000000000";
        }
        if (usdc == 100_000_000) {
            return
            hex"0100af88d065e77c8cC2239327C5EDb3A432268e583182aF49447D8a07e3bd95BD0d56f35241523fBab100000000000000000081f5676724d9447FA9385bE102ac3EAc297483Dd6233D62b3e149600000000000000000000000005f5e100000082aF49447D8a07e3bd95BD0d56f35241523fBab1af88d065e77c8cC2239327C5EDb3A432268e583100000000000000000000000000000000000000000020c49ba5e353f7800003e800000000000000000000000000000000";
        }
        return
        hex"0100af88d065e77c8cC2239327C5EDb3A432268e583182aF49447D8a07e3bd95BD0d56f35241523fBab100000000000000000040fab3b3926ca27FA9385bE102ac3EAc297483Dd6233D62b3e149600000000000000000000000002faf080000082aF49447D8a07e3bd95BD0d56f35241523fBab1af88d065e77c8cC2239327C5EDb3A432268e583100000000000000000000000000000000000000000020c49ba5e353f7800003e800000000000000000000000000000000";
    }
}
