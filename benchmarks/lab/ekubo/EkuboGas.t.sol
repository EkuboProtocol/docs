// SPDX-License-Identifier: ekubo-license-v1.eth
pragma solidity =0.8.33;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Core} from "ekubo/src/Core.sol";
import {Positions} from "ekubo/src/Positions.sol";
import {Router} from "ekubo/src/Router.sol";
import {PoolKey} from "ekubo/src/types/poolKey.sol";
import {PoolConfig, createFullRangePoolConfig, createConcentratedPoolConfig} from "ekubo/src/types/poolConfig.sol";
import {SqrtRatio} from "ekubo/src/types/sqrtRatio.sol";
import {NATIVE_TOKEN_ADDRESS} from "ekubo/src/math/constants.sol";
import {BaseRouter, RouteNode, TokenAmount, Swap} from "ekubo/src/base/BaseRouter.sol";
import {createSwapParameters} from "ekubo/src/types/swapParameters.sol";
import {BaseLocker} from "ekubo/src/base/BaseLocker.sol";
import {ICore} from "ekubo/src/interfaces/ICore.sol";
import {FlashAccountantLib} from "ekubo/src/libraries/FlashAccountantLib.sol";
import {PositionId, createPositionId} from "ekubo/src/types/positionId.sol";
import {PoolBalanceUpdate} from "ekubo/src/types/poolBalanceUpdate.sol";

/// @notice Bare core-level liquidity provision: lock, updatePosition, settle net.
///         No NFT, no protocol fees — the same tier as the v4/v3 direct mints.
contract BareMintRouter is BaseLocker {
    using FlashAccountantLib for *;

    constructor(ICore core) BaseLocker(core) {}

    function mint(PoolKey memory key, bytes24 salt, int32 tickLower, int32 tickUpper, int128 liquidityDelta, address payer)
        external
        returns (PoolBalanceUpdate balanceUpdate)
    {
        balanceUpdate =
            abi.decode(lock(abi.encode(key, salt, tickLower, tickUpper, liquidityDelta, payer, msg.sender)), (PoolBalanceUpdate));
    }

    function handleLockData(uint256, bytes memory data) internal override returns (bytes memory result) {
        (PoolKey memory key, bytes24 salt, int32 tickLower, int32 tickUpper, int128 liquidityDelta, address payer, address recipient) =
            abi.decode(data, (PoolKey, bytes24, int32, int32, int128, address, address));
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

contract EkuboGasTest is Test {
    Core core;
    Positions positions;
    Router router;
    BareMintRouter bareMint;

    MockERC20 tokenA;
    MockERC20 tokenB;
    MockERC20 tokenC;
    MockERC20 tokenD;

    PoolKey keyAB;
    PoolKey keyBC;
    PoolKey keyCD;
    PoolKey keyNative;

    // 0.3% fee in Q64 (matches Uniswap's 3000 fee tier)
    uint64 constant FEE_0_3 = 55340232221128655;
    // Concentrated code path (tick bitmap active), MIN..MAX position so swaps
    // never cross an initialized tick. Spacing 6000 fine-ticks ~= Uniswap spacing 60.
    uint32 constant TICK_SPACING = 6000;
    int32 constant RANGE_LOWER = -88722000; // -14787 * spacing
    int32 constant RANGE_UPPER = 88722000; // +14787 * spacing
    int32 constant INIT_TICK = 3050; // strictly inside a tick, not on a spacing multiple
    uint128 constant LIQUIDITY_AMOUNT = 1_000_000 ether;
        int128 constant SWAP_AMOUNT = 1 ether;

    function setUp() public {
        core = new Core();
        positions = new Positions(core, address(this), 0, 1);
        router = new Router(core, address(0), address(0));
        bareMint = new BareMintRouter(core);

        // One identical token artifact (solmate MockERC20, deployed via deployCode)
        // in every harness, so transfer costs cannot skew the comparison.
        tokenA = MockERC20(vm.deployCode("artifacts/MockERC20.json", abi.encode("TokenA", "A", 18)));
        tokenB = MockERC20(vm.deployCode("artifacts/MockERC20.json", abi.encode("TokenB", "B", 18)));
        tokenC = MockERC20(vm.deployCode("artifacts/MockERC20.json", abi.encode("TokenC", "C", 18)));
        tokenD = MockERC20(vm.deployCode("artifacts/MockERC20.json", abi.encode("TokenD", "D", 18)));
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

        keyAB = _fullRangeKey(address(tokenA), address(tokenB));
        keyBC = _fullRangeKey(address(tokenB), address(tokenC));
        keyCD = _fullRangeKey(address(tokenC), address(tokenD));
        keyNative = _fullRangeKey(NATIVE_TOKEN_ADDRESS, address(tokenB));

        core.initializePool(keyAB, INIT_TICK);
        core.initializePool(keyBC, INIT_TICK);
        core.initializePool(keyCD, INIT_TICK);
        core.initializePool(keyNative, INIT_TICK);

        tokenA.approve(address(positions), type(uint256).max);
        tokenB.approve(address(positions), type(uint256).max);
        tokenC.approve(address(positions), type(uint256).max);
        tokenD.approve(address(positions), type(uint256).max);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        tokenC.approve(address(router), type(uint256).max);
        tokenA.approve(address(bareMint), type(uint256).max);
        tokenB.approve(address(bareMint), type(uint256).max);

        positions.mintAndDeposit(keyAB, RANGE_LOWER, RANGE_UPPER, LIQUIDITY_AMOUNT, LIQUIDITY_AMOUNT, 0);
        positions.mintAndDeposit(keyBC, RANGE_LOWER, RANGE_UPPER, LIQUIDITY_AMOUNT, LIQUIDITY_AMOUNT, 0);
        positions.mintAndDeposit(keyCD, RANGE_LOWER, RANGE_UPPER, LIQUIDITY_AMOUNT, LIQUIDITY_AMOUNT, 0);
        positions.mintAndDeposit{value: LIQUIDITY_AMOUNT}(
            keyNative, RANGE_LOWER, RANGE_UPPER, LIQUIDITY_AMOUNT, LIQUIDITY_AMOUNT, 0
        );
    }

    function _fullRangeKey(address t0, address t1) internal pure returns (PoolKey memory) {
        return PoolKey({token0: t0, token1: t1, config: createConcentratedPoolConfig(FEE_0_3, TICK_SPACING, address(0))});
    }

    function _coolAll() internal {
        vm.cool(address(core));
        vm.cool(address(positions));
        vm.cool(address(router));
        vm.cool(address(bareMint));
        vm.cool(address(tokenA));
        vm.cool(address(tokenB));
        vm.cool(address(tokenC));
        vm.cool(address(tokenD));
        vm.cool(address(this));
    }

    function _route(PoolKey[] memory keys) internal pure returns (RouteNode[] memory route) {
        route = new RouteNode[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            route[i] = RouteNode(keys[i], SqrtRatio.wrap(0), 0);
        }
    }

    /// forge-config: default.isolate = true
    function test_gas_single_exactInput_erc20() public {
        _coolAll();
        router.swapAllowPartialFill(
            keyAB, createSwapParameters(SqrtRatio.wrap(0), SWAP_AMOUNT, false, 0)
        );
        vm.snapshotGasLastCall("ekubo single exact-input token0->token1 concentrated");
    }

    /// forge-config: default.isolate = true
    function test_gas_single_exactInput_erc20_reverse() public {
        _coolAll();
        router.swapAllowPartialFill(
            keyAB, createSwapParameters(SqrtRatio.wrap(0), SWAP_AMOUNT, true, 0)
        );
        vm.snapshotGasLastCall("ekubo single exact-input token1->token0 concentrated");
    }

    /// forge-config: default.isolate = true
    function test_gas_single_exactInput_native() public {
        _coolAll();
        router.swapAllowPartialFill{value: uint128(SWAP_AMOUNT)}(
            keyNative, createSwapParameters(SqrtRatio.wrap(0), SWAP_AMOUNT, false, 0)
        );
        vm.snapshotGasLastCall("ekubo single exact-input native->ERC20 concentrated");
    }

    /// forge-config: default.isolate = true
    function test_gas_oneHop_multihopPath() public {
        PoolKey[] memory keys = new PoolKey[](1);
        keys[0] = keyAB;
        _coolAll();
        router.multihopSwap(
            Swap(_route(keys), TokenAmount({token: address(tokenA), amount: SWAP_AMOUNT})), type(int256).min
        );
        vm.snapshotGasLastCall("ekubo one-hop exact-input single lock concentrated");
    }

    /// forge-config: default.isolate = true
    function test_gas_twoHop_exactInput() public {
        PoolKey[] memory keys = new PoolKey[](2);
        keys[0] = keyAB;
        keys[1] = keyBC;
        _coolAll();
        router.multihopSwap(
            Swap(_route(keys), TokenAmount({token: address(tokenA), amount: SWAP_AMOUNT})), type(int256).min
        );
        vm.snapshotGasLastCall("ekubo two-hop exact-input single lock concentrated");
    }

    /// forge-config: default.isolate = true
    function test_gas_threeHop_exactInput() public {
        PoolKey[] memory keys = new PoolKey[](3);
        keys[0] = keyAB;
        keys[1] = keyBC;
        keys[2] = keyCD;
        _coolAll();
        router.multihopSwap(
            Swap(_route(keys), TokenAmount({token: address(tokenA), amount: SWAP_AMOUNT})), type(int256).min
        );
        vm.snapshotGasLastCall("ekubo three-hop exact-input single lock concentrated");
    }

    /// forge-config: default.isolate = true
    function test_gas_mint_bare() public {
        _coolAll();
        bareMint.mint(keyAB, bytes24(uint192(777)), RANGE_LOWER, RANGE_UPPER, 1e24, address(this));
        vm.snapshotGasLastCall("ekubo mint bare core position");
    }

    /// forge-config: default.isolate = true
    function test_gas_mint_fullRange() public {
        _coolAll();
        positions.mintAndDeposit(keyAB, RANGE_LOWER, RANGE_UPPER, LIQUIDITY_AMOUNT, LIQUIDITY_AMOUNT, 0);
        vm.snapshotGasLastCall("ekubo mint concentrated position");
    }

    receive() external payable {}
}
