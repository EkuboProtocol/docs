// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {Test} from "forge-std/Test.sol";

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
    function ownerOf(uint256 tokenId) external view returns (address);
    function factory() external view returns (address);
    function name() external view returns (string memory);
}

interface IUniswapV3PoolLike {
    function tickSpacing() external view returns (int24);
    function fee() external view returns (uint24);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function liquidity() external view returns (uint128);
    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );
}

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

/// @notice Mainnet-fork mint through the REAL deployed Uniswap v3 NonfungiblePositionManager
///         on the REAL USDT/USDC fee-100 pool (the same pool as the fork swap legs).
///         Full-range position (tick spacing 1: MIN_TICK..MAX_TICK), ~10,000 USDC + ~10,000 USDT,
///         recipient = this contract, deadline = block.timestamp. One identical unmeasured
///         mint first (a separate NFT / separate position: warm-up initializes the boundary
///         ticks if they were cold and warms the manager's per-pool state); every call is its
///         own transaction (`isolate`), so the snapshot is the execution gas of the measured mint.
///         USDT returns no returndata: approve via low-level call.
///         Run with: --fork-url <mainnet archive> --fork-block-number 25991868
contract ForkMintV3Test is Test {
    INonfungiblePositionManager constant NPM = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    IUniswapV3PoolLike constant POOL = IUniswapV3PoolLike(0x3416cF6C708Da44DB2624D63ea0AAef7113527C6);
    address constant FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    int24 constant TICK_LOWER = -887272; // TickMath.MIN_TICK, usable at spacing 1
    int24 constant TICK_UPPER = 887272; // TickMath.MAX_TICK
    uint256 constant AMOUNT = 10_000_000_000; // 10,000 (6 decimals) per side

    function _setup() internal {
        assertGt(address(NPM).code.length, 0, "NPM has code on fork");
        assertEq(NPM.factory(), FACTORY, "NPM factory");
        assertEq(NPM.name(), "Uniswap V3 Positions NFT-V1", "NPM name");
        assertEq(POOL.token0(), USDC, "pool token0");
        assertEq(POOL.token1(), USDT, "pool token1");
        assertEq(POOL.fee(), 100, "pool fee");
        assertEq(POOL.tickSpacing(), 1, "pool spacing");

        deal(USDC, address(this), 100_000_000_000);
        deal(USDT, address(this), 100_000_000_000);
        assertTrue(IERC20Like(USDC).approve(address(NPM), type(uint256).max), "usdc approve");
        (bool ok,) = USDT.call(abi.encodeWithSignature("approve(address,uint256)", address(NPM), type(uint256).max));
        assertTrue(ok, "usdt approve");
        assertEq(IERC20Like(USDC).allowance(address(this), address(NPM)), type(uint256).max);
        assertEq(IERC20Like(USDT).allowance(address(this), address(NPM)), type(uint256).max);
    }

    function _mint() internal returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {
        return _mintRange(TICK_LOWER, TICK_UPPER);
    }

    function _mintRange(int24 lower, int24 upper)
        internal
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        return NPM.mint(
            INonfungiblePositionManager.MintParams({
                token0: USDC,
                token1: USDT,
                fee: 100,
                tickLower: lower,
                tickUpper: upper,
                amount0Desired: AMOUNT,
                amount1Desired: AMOUNT,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );
    }

    /// forge-config: default.isolate = true
    function test_fork_mint_v3_npm_fullRange() public {
        _setup();
        (,,,,,,, bool lowerInit) = POOL.ticks(TICK_LOWER);
        (,,,,,,, bool upperInit) = POOL.ticks(TICK_UPPER);
        emit log_named_string("v3 boundary ticks initialized before warm-up", lowerInit && upperInit ? "yes" : "no");
        uint128 poolLiqBefore = POOL.liquidity();

        // warm-up: a separate position (new tokenId); unmeasured for the headline, recorded for context
        (uint256 warmId, uint128 warmLiq,,) = _mint();
        vm.snapshotGasLastCall("fork v3 NPM mint full-range USDC/USDT fee-100 (first, warm-up)");
        assertGt(warmLiq, 0);
        assertEq(NPM.ownerOf(warmId), address(this));

        (,,,,,,, lowerInit) = POOL.ticks(TICK_LOWER);
        (,,,,,,, upperInit) = POOL.ticks(TICK_UPPER);
        assertTrue(lowerInit && upperInit, "boundary ticks initialized before measured mint");

        uint256 usdcBefore = IERC20Like(USDC).balanceOf(address(this));
        uint256 usdtBefore = IERC20Like(USDT).balanceOf(address(this));

        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) = _mint();
        vm.snapshotGasLastCall("fork v3 NPM mint full-range USDC/USDT fee-100 (measured)");

        // proof of execution
        assertTrue(tokenId != warmId, "new NFT");
        assertGt(liquidity, 0, "liquidity > 0");
        assertEq(NPM.ownerOf(tokenId), address(this), "NFT owned by recipient");
        (,,,,,,, uint128 posLiq,,,,) = NPM.positions(tokenId);
        assertEq(posLiq, liquidity, "position liquidity recorded");
        assertEq(IERC20Like(USDC).balanceOf(address(this)), usdcBefore - amount0, "USDC moved");
        assertEq(IERC20Like(USDT).balanceOf(address(this)), usdtBefore - amount1, "USDT moved");
        assertGt(amount0, 0);
        assertGt(amount1, 0);
        assertEq(POOL.liquidity(), poolLiqBefore + warmLiq + liquidity, "pool active liquidity increased");

        vm.snapshotValue("fork v3 NPM mint tokenId", tokenId);
        vm.snapshotValue("fork v3 NPM mint liquidity", liquidity);
        vm.snapshotValue("fork v3 NPM mint amount0 (USDC, 6 decimals)", amount0);
        vm.snapshotValue("fork v3 NPM mint amount1 (USDT, 6 decimals)", amount1);
        emit log_named_uint("v3 tokenId", tokenId);
        emit log_named_uint("v3 liquidity", liquidity);
        emit log_named_uint("v3 amount0 USDC", amount0);
        emit log_named_uint("v3 amount1 USDT", amount1);
    }

    /// @dev Same mint after the same full-range warm-up, but on a range whose boundary ticks are
    ///      NOT initialized on-chain (asserted), so the figure includes v3 tick initialization.
    /// forge-config: default.isolate = true
    function test_fork_mint_v3_npm_coldBoundaryTicks() public {
        _setup();
        int24 lower = -500_001;
        int24 upper = 500_001;
        (,,,,,,, bool lowerInit) = POOL.ticks(lower);
        (,,,,,,, bool upperInit) = POOL.ticks(upper);
        assertTrue(!lowerInit && !upperInit, "boundary ticks cold before mint");

        (uint256 warmId,,,) = _mint(); // full-range warm-up, as in the headline test
        assertEq(NPM.ownerOf(warmId), address(this));

        (uint256 tokenId, uint128 liquidity,,) = _mintRange(lower, upper);
        vm.snapshotGasLastCall("fork v3 NPM mint USDC/USDT fee-100, cold boundary ticks");
        assertGt(liquidity, 0);
        assertEq(NPM.ownerOf(tokenId), address(this));
        (,,,,,,, lowerInit) = POOL.ticks(lower);
        (,,,,,,, upperInit) = POOL.ticks(upper);
        assertTrue(lowerInit && upperInit, "boundary ticks initialized by the mint");
    }
}
