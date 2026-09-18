// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {Test} from "forge-std/Test.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";

/// @dev Minimal surface of the deployed v4 PositionManager (v4-periphery).
interface IV4PositionManager {
    function modifyLiquidities(bytes calldata unlockData, uint256 deadline) external payable;
    function nextTokenId() external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function getPositionLiquidity(uint256 tokenId) external view returns (uint128);
    function poolKeys(bytes25 poolId) external view returns (Currency, Currency, uint24, int24, IHooks);
    function poolManager() external view returns (address);
    function permit2() external view returns (address);
    function name() external view returns (string memory);
}

interface IPermit2Like {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
    function allowance(address user, address token, address spender)
        external
        view
        returns (uint160 amount, uint48 expiration, uint48 nonce);
}

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

/// @notice Mainnet-fork mint through the REAL deployed Uniswap v4 PositionManager
///         (canonical mainnet address per docs.uniswap.org/contracts/v4/deployments, verified on the
///         fork: name, poolManager(), permit2()) on the REAL USDC/USDT fee-100 hookless pool used by
///         the fork swap leg. Full-range position (tick spacing 1: MIN_TICK..MAX_TICK), liquidity
///         sized to ~10,000 USDC + ~10,000 USDT, owner = this contract, deadline = block.timestamp.
///         Actions: MINT_POSITION (0x02) + SETTLE_PAIR (0x0d); tokens are pulled through Permit2, as
///         for every PositionManager user (ERC20 approval to Permit2 + Permit2 allowance to the manager,
///         both granted in setup and not measured). One identical unmeasured mint first (separate NFT);
///         every call is its own transaction (`isolate`).
///         Run with: --fork-url <mainnet archive> --fork-block-number 25991868
contract ForkMintV4Test is Test {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    IPoolManager constant MANAGER = IPoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);
    IV4PositionManager constant POSM = IV4PositionManager(0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e);
    IPermit2Like constant PERMIT2 = IPermit2Like(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    bytes32 constant EXPECTED_POOL_ID = 0xe018f09af38956affdfeab72c2cefbcd4e6fee44d09df7525ec9dba3e51356a5;

    uint8 constant MINT_POSITION = 0x02;
    uint8 constant SETTLE_PAIR = 0x0d;
    int24 constant TICK_LOWER = -887272; // TickMath.MIN_TICK, usable at spacing 1
    int24 constant TICK_UPPER = 887272;
    uint256 constant AMOUNT = 10_000_000_000; // 10,000 (6 decimals) per side

    PoolKey key;

    function _setup() internal {
        assertGt(address(POSM).code.length, 0, "PositionManager has code on fork");
        assertEq(POSM.poolManager(), address(MANAGER), "posm.poolManager");
        assertEq(POSM.permit2(), address(PERMIT2), "posm.permit2");
        assertEq(POSM.name(), "Uniswap v4 Positions NFT", "posm name");

        key = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(USDT),
            fee: 100,
            tickSpacing: 1,
            hooks: IHooks(address(0))
        });
        assertEq(PoolId.unwrap(key.toId()), EXPECTED_POOL_ID, "pool id matches fork swap leg");
        (uint160 sqrtP,,,) = MANAGER.getSlot0(key.toId());
        assertGt(sqrtP, 0, "pool initialized");

        deal(USDC, address(this), 100_000_000_000);
        deal(USDT, address(this), 100_000_000_000);
        assertTrue(IERC20Like(USDC).approve(address(PERMIT2), type(uint256).max), "usdc approve permit2");
        (bool ok,) = USDT.call(abi.encodeWithSignature("approve(address,uint256)", address(PERMIT2), type(uint256).max));
        assertTrue(ok, "usdt approve permit2");
        PERMIT2.approve(USDC, address(POSM), type(uint160).max, type(uint48).max);
        PERMIT2.approve(USDT, address(POSM), type(uint160).max, type(uint48).max);
        (uint160 a0,,) = PERMIT2.allowance(address(this), USDC, address(POSM));
        (uint160 a1,,) = PERMIT2.allowance(address(this), USDT, address(POSM));
        assertEq(a0, type(uint160).max);
        assertEq(a1, type(uint160).max);
    }

    function _liquidityForAmounts() internal view returns (uint128) {
        (uint160 sqrtP,,,) = MANAGER.getSlot0(key.toId());
        return LiquidityAmounts.getLiquidityForAmounts(
            sqrtP, TickMath.getSqrtPriceAtTick(TICK_LOWER), TickMath.getSqrtPriceAtTick(TICK_UPPER), AMOUNT, AMOUNT
        );
    }

    function _mint(uint128 liquidity) internal returns (uint256 tokenId) {
        return _mintRange(TICK_LOWER, TICK_UPPER, liquidity);
    }

    function _mintRange(int24 lower, int24 upper, uint128 liquidity) internal returns (uint256 tokenId) {
        tokenId = POSM.nextTokenId();
        bytes memory actions = abi.encodePacked(MINT_POSITION, SETTLE_PAIR);
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(
            key, lower, upper, uint256(liquidity), uint128(AMOUNT), uint128(AMOUNT), address(this), bytes("")
        );
        params[1] = abi.encode(key.currency0, key.currency1);
        POSM.modifyLiquidities(abi.encode(actions, params), block.timestamp);
    }

    /// forge-config: default.isolate = true
    function test_fork_mint_v4_posm_fullRange() public {
        _setup();
        bytes25 shortId = bytes25(PoolId.unwrap(key.toId()));
        (Currency c0, Currency c1,,,) = POSM.poolKeys(shortId);
        emit log_named_string(
            "v4 PositionManager already knows this pool key before warm-up",
            Currency.unwrap(c0) == USDC && Currency.unwrap(c1) == USDT ? "yes" : "no"
        );
        (uint128 lowerGross,) = MANAGER.getTickLiquidity(key.toId(), TICK_LOWER);
        (uint128 upperGross,) = MANAGER.getTickLiquidity(key.toId(), TICK_UPPER);
        emit log_named_string(
            "v4 boundary ticks initialized before warm-up", lowerGross > 0 && upperGross > 0 ? "yes" : "no"
        );
        uint128 poolLiqBefore = MANAGER.getLiquidity(key.toId());
        uint128 liquidity = _liquidityForAmounts();
        assertGt(liquidity, 0);

        // warm-up: a separate position (new tokenId); unmeasured for the headline, recorded for context
        uint256 warmId = _mint(liquidity);
        vm.snapshotGasLastCall("fork v4 PositionManager mint full-range USDC/USDT fee-100 (first, warm-up)");
        assertEq(POSM.ownerOf(warmId), address(this));
        assertEq(POSM.getPositionLiquidity(warmId), liquidity);

        (c0, c1,,,) = POSM.poolKeys(shortId);
        assertTrue(Currency.unwrap(c0) == USDC && Currency.unwrap(c1) == USDT, "pool key stored before measured mint");
        (lowerGross,) = MANAGER.getTickLiquidity(key.toId(), TICK_LOWER);
        (upperGross,) = MANAGER.getTickLiquidity(key.toId(), TICK_UPPER);
        assertTrue(lowerGross > 0 && upperGross > 0, "boundary ticks initialized before measured mint");

        uint256 usdcBefore = IERC20Like(USDC).balanceOf(address(this));
        uint256 usdtBefore = IERC20Like(USDT).balanceOf(address(this));

        uint256 tokenId = _mint(liquidity);
        vm.snapshotGasLastCall("fork v4 PositionManager mint full-range USDC/USDT fee-100 (measured)");

        // proof of execution
        assertEq(tokenId, warmId + 1, "new NFT");
        assertEq(POSM.ownerOf(tokenId), address(this), "NFT owned by recipient");
        assertEq(POSM.getPositionLiquidity(tokenId), liquidity, "position liquidity recorded");
        uint256 amount0 = usdcBefore - IERC20Like(USDC).balanceOf(address(this));
        uint256 amount1 = usdtBefore - IERC20Like(USDT).balanceOf(address(this));
        assertGt(amount0, 0, "USDC moved");
        assertGt(amount1, 0, "USDT moved");
        assertLe(amount0, AMOUNT);
        assertLe(amount1, AMOUNT);
        assertEq(MANAGER.getLiquidity(key.toId()), poolLiqBefore + 2 * liquidity, "pool active liquidity increased");

        vm.snapshotValue("fork v4 PositionManager mint tokenId", tokenId);
        vm.snapshotValue("fork v4 PositionManager mint liquidity", liquidity);
        vm.snapshotValue("fork v4 PositionManager mint amount0 (USDC, 6 decimals)", amount0);
        vm.snapshotValue("fork v4 PositionManager mint amount1 (USDT, 6 decimals)", amount1);
        emit log_named_uint("v4 tokenId", tokenId);
        emit log_named_uint("v4 liquidity", liquidity);
        emit log_named_uint("v4 amount0 USDC", amount0);
        emit log_named_uint("v4 amount1 USDT", amount1);
    }

    /// @dev Same mint after the same full-range warm-up, but on a range whose boundary ticks are
    ///      NOT initialized on-chain (asserted), so the figure includes v4 tick initialization.
    /// forge-config: default.isolate = true
    function test_fork_mint_v4_posm_coldBoundaryTicks() public {
        _setup();
        int24 lower = -500_001;
        int24 upper = 500_001;
        (uint128 lowerGross,) = MANAGER.getTickLiquidity(key.toId(), lower);
        (uint128 upperGross,) = MANAGER.getTickLiquidity(key.toId(), upper);
        assertTrue(lowerGross == 0 && upperGross == 0, "boundary ticks cold before mint");

        uint128 liquidity = _liquidityForAmounts();
        uint256 warmId = _mint(liquidity); // full-range warm-up, as in the headline test
        assertEq(POSM.ownerOf(warmId), address(this));

        (uint160 sqrtP,,,) = MANAGER.getSlot0(key.toId());
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            sqrtP, TickMath.getSqrtPriceAtTick(lower), TickMath.getSqrtPriceAtTick(upper), AMOUNT, AMOUNT
        );
        uint256 tokenId = _mintRange(lower, upper, liq);
        vm.snapshotGasLastCall("fork v4 PositionManager mint USDC/USDT fee-100, cold boundary ticks");
        assertEq(POSM.ownerOf(tokenId), address(this));
        assertEq(POSM.getPositionLiquidity(tokenId), liq);
        (lowerGross,) = MANAGER.getTickLiquidity(key.toId(), lower);
        (upperGross,) = MANAGER.getTickLiquidity(key.toId(), upper);
        assertTrue(lowerGross > 0 && upperGross > 0, "boundary ticks initialized by the mint");
    }
}
