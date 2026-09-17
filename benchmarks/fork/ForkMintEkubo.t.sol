// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {Test} from "forge-std/Test.sol";

/// @dev Minimal surface of the deployed canonical Ekubo Positions (evm-contracts v3.1.1 generation).
///      PoolKey is (address token0, address token1, bytes32 config); mintAndDeposit returns the new
///      NFT id, the liquidity added and the amounts pulled from msg.sender.
interface IEkuboPositions {
    struct PoolKey {
        address token0;
        address token1;
        bytes32 config;
    }

    function mintAndDeposit(
        PoolKey memory poolKey,
        int32 tickLower,
        int32 tickUpper,
        uint128 maxAmount0,
        uint128 maxAmount1,
        uint128 minLiquidity
    ) external payable returns (uint256 id, uint128 liquidity, uint128 amount0, uint128 amount1);
    function mintAndDepositWithSalt(
        bytes32 salt,
        PoolKey memory poolKey,
        int32 tickLower,
        int32 tickUpper,
        uint128 maxAmount0,
        uint128 maxAmount1,
        uint128 minLiquidity
    ) external payable returns (uint256 id, uint128 liquidity, uint128 amount0, uint128 amount1);
    function getPositionFeesAndLiquidity(uint256 id, PoolKey memory poolKey, int32 tickLower, int32 tickUpper)
        external
        view
        returns (uint128 liquidity, uint128 principal0, uint128 principal1, uint128 fees0, uint128 fees1);
    function ownerOf(uint256 id) external view returns (address);
    function name() external view returns (string memory);
}

interface IEkuboCoreLike {
    function nextInitializedTick(bytes32 poolId, int32 fromTick, uint32 tickSpacing, uint256 skipAhead)
        external
        view
        returns (int32 tick, bool isInitialized);
}

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

/// @notice Mainnet-fork mint through the REAL deployed canonical Ekubo Positions NFT contract
///         (address from the docs contracts reference, verified on the fork: code + name) on the REAL
///         live USDC/USDT concentrated pool used by the fork swap leg (spacing 50, no extension).
///         Pool id re-derived as keccak256(token0, token1, config) and asserted against the id used
///         by the swap leg, and the pool's packed state in Core is asserted initialized.
///         Widest position aligned to spacing 50 (+-88,722,800; MIN/MAX_TICK are +-88,722,835),
///         max amounts 10,000 USDC + 10,000 USDT, NFT to msg.sender (this contract). Tokens are
///         pulled by Positions via transferFrom (ERC20 approval to Positions in setup, not measured).
///         One identical unmeasured mint first (separate NFT; it uses mintAndDepositWithSalt with an
///         explicit salt because mint() derives its salt from prevrandao and remaining gas, which two
///         identical isolated calls share, so a plain repeat would collide on the same NFT id). The
///         measured call is the plain user-facing mintAndDeposit. Every call is its own transaction
///         (`isolate`). USDT returns no returndata: approve via low-level call.
///         Run with: --fork-url <mainnet archive> --fork-block-number 25991868
contract ForkMintEkuboTest is Test {
    IEkuboPositions constant POSITIONS = IEkuboPositions(0x02D9876A21AF7545f8632C3af76eC90b5ad4b66D);
    address constant CORE = 0x00000000000014aA86C5d3c41765bb24e11bd701;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    bytes32 constant CONFIG = 0x0000000000000000000000000000000000000000000053e2d6238da480000032;
    bytes32 constant EXPECTED_POOL_ID = 0x6fde3244f6fa747ae318aba6e982a4281febad4d22e3b134aa299a83a951895d;

    int32 constant TICK_LOWER = -88722800; // -1774456 * 50 (MIN_TICK is -88722835)
    int32 constant TICK_UPPER = 88722800;
    uint128 constant AMOUNT = 10_000_000_000; // 10,000 (6 decimals) per side

    IEkuboPositions.PoolKey key;

    function _setup() internal {
        assertGt(address(POSITIONS).code.length, 0, "Positions has code on fork");
        assertGt(CORE.code.length, 0, "Core has code on fork");
        assertEq(POSITIONS.name(), "Ekubo Positions", "positions name");

        key = IEkuboPositions.PoolKey({token0: USDC, token1: USDT, config: CONFIG});
        bytes32 poolId = keccak256(abi.encode(USDC, USDT, CONFIG));
        assertEq(poolId, EXPECTED_POOL_ID, "pool id matches fork swap leg");
        // Core packs pool state at slot poolId: sqrtRatio (96 bits) | tick (32) | liquidity (128)
        bytes32 state = vm.load(CORE, poolId);
        assertGt(uint256(state) >> 160, 0, "pool initialized (sqrtRatio != 0)");
        assertEq(uint256(CONFIG) & 0x7fffffff, 50, "tick spacing 50");
        assertTrue((uint256(CONFIG) & 0x80000000) != 0, "concentrated");

        deal(USDC, address(this), 100_000_000_000);
        deal(USDT, address(this), 100_000_000_000);
        assertTrue(IERC20Like(USDC).approve(address(POSITIONS), type(uint256).max), "usdc approve");
        (bool ok,) =
            USDT.call(abi.encodeWithSignature("approve(address,uint256)", address(POSITIONS), type(uint256).max));
        assertTrue(ok, "usdt approve");
        assertEq(IERC20Like(USDC).allowance(address(this), address(POSITIONS)), type(uint256).max);
        assertEq(IERC20Like(USDT).allowance(address(this), address(POSITIONS)), type(uint256).max);
    }

    function _mint() internal returns (uint256 id, uint128 liquidity, uint128 amount0, uint128 amount1) {
        return POSITIONS.mintAndDeposit(key, TICK_LOWER, TICK_UPPER, AMOUNT, AMOUNT, 0);
    }

    /// @dev Whether `tick` is an initialized tick of the pool, via Core's bitmap walk from the
    ///      previous spacing multiple.
    function _tickInitialized(bytes32 poolId, int32 tick) internal view returns (bool) {
        (int32 found, bool init) = IEkuboCoreLike(CORE).nextInitializedTick(poolId, tick - 50, 50, 0);
        return init && found == tick;
    }

    /// forge-config: default.isolate = true
    function test_fork_mint_ekubo_positions_fullRange() public {
        _setup();
        bytes32 poolId = keccak256(abi.encode(USDC, USDT, CONFIG));
        uint128 poolLiqBefore = uint128(uint256(vm.load(CORE, poolId)));
        emit log_named_string(
            "ekubo boundary ticks initialized before warm-up",
            _tickInitialized(poolId, TICK_LOWER) && _tickInitialized(poolId, TICK_UPPER) ? "yes" : "no"
        );

        // warm-up: a separate position (explicit salt -> distinct NFT id); unmeasured for the headline,
        // recorded for context
        (uint256 warmId, uint128 warmLiq,,) =
            POSITIONS.mintAndDepositWithSalt(bytes32(uint256(1)), key, TICK_LOWER, TICK_UPPER, AMOUNT, AMOUNT, 0);
        vm.snapshotGasLastCall("fork ekubo Positions mintAndDepositWithSalt full-range USDC/USDT (first, warm-up)");
        assertGt(warmLiq, 0);
        assertEq(POSITIONS.ownerOf(warmId), address(this));
        assertTrue(
            _tickInitialized(poolId, TICK_LOWER) && _tickInitialized(poolId, TICK_UPPER),
            "boundary ticks initialized before measured mint"
        );

        uint256 usdcBefore = IERC20Like(USDC).balanceOf(address(this));
        uint256 usdtBefore = IERC20Like(USDT).balanceOf(address(this));

        (uint256 id, uint128 liquidity, uint128 amount0, uint128 amount1) = _mint();
        vm.snapshotGasLastCall("fork ekubo Positions mintAndDeposit full-range USDC/USDT (measured)");

        // proof of execution
        assertTrue(id != warmId, "new NFT");
        assertGt(liquidity, 0, "liquidity > 0");
        assertEq(POSITIONS.ownerOf(id), address(this), "NFT owned by minter");
        (uint128 posLiq,,,,) = POSITIONS.getPositionFeesAndLiquidity(id, key, TICK_LOWER, TICK_UPPER);
        assertEq(posLiq, liquidity, "position liquidity recorded in Core");
        assertEq(IERC20Like(USDC).balanceOf(address(this)), usdcBefore - amount0, "USDC moved");
        assertEq(IERC20Like(USDT).balanceOf(address(this)), usdtBefore - amount1, "USDT moved");
        assertGt(amount0, 0);
        assertGt(amount1, 0);
        assertLe(amount0, AMOUNT);
        assertLe(amount1, AMOUNT);
        uint128 poolLiqAfter = uint128(uint256(vm.load(CORE, poolId)));
        assertEq(poolLiqAfter, poolLiqBefore + warmLiq + liquidity, "pool active liquidity increased");

        vm.snapshotValue("fork ekubo Positions mint id", id);
        vm.snapshotValue("fork ekubo Positions mint liquidity", liquidity);
        vm.snapshotValue("fork ekubo Positions mint amount0 (USDC, 6 decimals)", amount0);
        vm.snapshotValue("fork ekubo Positions mint amount1 (USDT, 6 decimals)", amount1);
        emit log_named_uint("ekubo id", id);
        emit log_named_uint("ekubo liquidity", liquidity);
        emit log_named_uint("ekubo amount0 USDC", amount0);
        emit log_named_uint("ekubo amount1 USDT", amount1);
    }

    /// @dev Same mint after the same full-range warm-up, but on a range whose boundary ticks are
    ///      NOT initialized on-chain (asserted), so the figure includes Ekubo tick initialization.
    /// forge-config: default.isolate = true
    function test_fork_mint_ekubo_positions_coldBoundaryTicks() public {
        _setup();
        bytes32 poolId = keccak256(abi.encode(USDC, USDT, CONFIG));
        int32 lower = -88_722_750; // -1774455 * 50
        int32 upper = 88_722_750;
        assertTrue(!_tickInitialized(poolId, lower) && !_tickInitialized(poolId, upper), "boundary ticks cold");

        (uint256 warmId,,,) =
            POSITIONS.mintAndDepositWithSalt(bytes32(uint256(1)), key, TICK_LOWER, TICK_UPPER, AMOUNT, AMOUNT, 0);
        assertEq(POSITIONS.ownerOf(warmId), address(this));

        (uint256 id, uint128 liquidity,,) = POSITIONS.mintAndDeposit(key, lower, upper, AMOUNT, AMOUNT, 0);
        vm.snapshotGasLastCall("fork ekubo Positions mintAndDeposit USDC/USDT, cold boundary ticks");
        assertGt(liquidity, 0);
        assertEq(POSITIONS.ownerOf(id), address(this));
        assertTrue(_tickInitialized(poolId, lower) && _tickInitialized(poolId, upper), "ticks initialized by mint");
    }
}
