// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {ProdCommon, IFreshToken} from "./ProdCommon.sol";

interface IUniswapV3Factory {
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IUniswapV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function initialize(uint160 sqrtPriceX96) external;
    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount, bytes calldata data)
        external
        returns (uint256 amount0, uint256 amount1);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data)
        external
        returns (int256 amount0, int256 amount1);
    function slot0()
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked);
    function liquidity() external view returns (uint128);
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function factory() external view returns (address);
    function WETH9() external view returns (address);
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

/// @notice Minimal N-hop exact-input router over v3 pools with the production SwapRouter's
///         token flow (first hop paid straight from the user, intermediate outputs held by
///         the router and paid forward, last hop delivered to the recipient): 2 transfers
///         per pool. Same contract as in the lab harness.
contract V3MinimalRouter {
    uint160 constant MIN_LIMIT = 4295128740; // MIN_SQRT_RATIO + 1

    function multiHop(IUniswapV3Pool[] memory pools, address[] memory tokensIn, int256 amountIn, address recipient)
        external
        returns (int256 out)
    {
        int256 amount = amountIn;
        address payer = msg.sender;
        for (uint256 i = 0; i < pools.length; i++) {
            bool last = i == pools.length - 1;
            (, int256 a1) =
                pools[i].swap(last ? recipient : address(this), true, amount, MIN_LIMIT, abi.encode(tokensIn[i], payer));
            amount = -a1;
            require(amount > 0, "no hop output");
            payer = address(this);
        }
        out = amount;
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256, bytes calldata data) external {
        (address tokenIn, address payer) = abi.decode(data, (address, address));
        uint256 owed = uint256(amount0Delta); // every hop is zeroForOne
        if (payer == address(this)) IFreshToken(tokenIn).transfer(msg.sender, owed);
        else IFreshToken(tokenIn).transferFrom(payer, msg.sender, owed);
    }
}

/// @notice Production Uniswap v3 on a fork of the latest mainnet block, fresh tokens: the
///         deployed factory creates the pools, the deployed SwapRouter is the production
///         path, the minimal router above is the lab counterpart. Full-range positions of
///         the liquidity that 1M/1M tokens buy at the init price (matching the other two
///         harnesses), minted directly in setup (unmeasured). One identical unmeasured call
///         precedes every measurement; every call is isolated (execution gas net of
///         refunds, excluding the 21,000 base and the calldata recorded next to it).
contract ProdV3Test is ProdCommon {
    IUniswapV3Factory constant FACTORY = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    ISwapRouter constant ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    uint24 constant FEE = 3000;
    int24 constant TICK_LOWER = -887220;
    int24 constant TICK_UPPER = 887220;
    uint160 constant INIT_SQRT_PRICE = 79347087983665984109010747392; // tick 30, strictly inside (spacing 60)
    uint128 constant LIQUIDITY = 998501199320305883812938; // 1M/1M full-range at the init price

    IUniswapV3Pool poolAB;
    IUniswapV3Pool poolBC;
    IUniswapV3Pool poolCD;
    IUniswapV3Pool poolWethB;
    V3MinimalRouter minimal;

    function _setup() internal {
        assertEq(block.chainid, 1, "mainnet fork");
        assertEq(ROUTER.factory(), address(FACTORY), "production SwapRouter and factory");
        assertEq(ROUTER.WETH9(), WETH, "WETH9");
        _deployTokens();
        deal(WETH, address(this), 10_000_000 ether);

        poolAB = _pool(TOKEN_A, TOKEN_B);
        poolBC = _pool(TOKEN_B, TOKEN_C);
        poolCD = _pool(TOKEN_C, TOKEN_D);
        poolWethB = _pool(TOKEN_B, WETH); // TOKEN_B < WETH by address
        minimal = new V3MinimalRouter();
        IFreshToken(TOKEN_A).approve(address(ROUTER), type(uint256).max);
        IFreshToken(TOKEN_A).approve(address(minimal), type(uint256).max);
        assertEq(IFreshToken(TOKEN_A).allowance(address(this), address(ROUTER)), type(uint256).max, "max approval");
    }

    function _pool(address t0, address t1) internal returns (IUniswapV3Pool pool) {
        assertLt(uint160(t0), uint160(t1), "ordered");
        assertEq(FACTORY.getPool(t0, t1, FEE), address(0), "pool must not exist yet");
        pool = IUniswapV3Pool(FACTORY.createPool(t0, t1, FEE));
        pool.initialize(INIT_SQRT_PRICE);
        pool.mint(address(this), TICK_LOWER, TICK_UPPER, LIQUIDITY, "");
        assertEq(pool.liquidity(), LIQUIDITY);
    }

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata) external {
        if (amount0Owed > 0) IFreshToken(IUniswapV3Pool(msg.sender).token0()).transfer(msg.sender, amount0Owed);
        if (amount1Owed > 0) IFreshToken(IUniswapV3Pool(msg.sender).token1()).transfer(msg.sender, amount1Owed);
    }

    function _tick(IUniswapV3Pool pool) internal view returns (int24 tick) {
        (, tick,,,,,) = pool.slot0();
    }

    function _call(string memory name, address to, uint256 value, bytes memory data, IUniswapV3Pool lastPool, address tokenOut)
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

    // ---- production SwapRouter ----

    function _single(address tokenIn, address tokenOut, uint256 value) internal pure returns (bytes memory) {
        return abi.encodeCall(
            ISwapRouter.exactInputSingle,
            (
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    fee: FEE,
                    recipient: 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496,
                    deadline: type(uint256).max,
                    amountIn: value == 0 ? SWAP_AMOUNT : value,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            )
        );
    }

    function _path(uint256 n) internal pure returns (bytes memory path) {
        path = abi.encodePacked(TOKEN_A, FEE, TOKEN_B);
        if (n > 1) path = abi.encodePacked(path, FEE, TOKEN_C);
        if (n > 2) path = abi.encodePacked(path, FEE, TOKEN_D);
    }

    function _router(string memory file, string memory name, bytes memory data, uint256 value, uint256 n, address tokenOut, uint256 minOut)
        internal
    {
        _setup();
        // resolved after _setup(): the pools are storage, so they must not be read before it
        IUniswapV3Pool last = n == 0 ? poolWethB : (n == 1 ? poolAB : (n == 2 ? poolBC : poolCD));
        _call("", address(ROUTER), value, data, last, tokenOut); // warm-up, unmeasured
        uint256 out = _call(name, address(ROUTER), value, data, last, tokenOut);
        assertGe(out, minOut, "output sanity");
        assertLe(out, (SWAP_AMOUNT * 101) / 100, "output sanity"); // pools sit at tick 30.5, so 1 A buys ~1.003 B before the 0.3% fee
        _recordCalldata(name, file, data);
    }

    /// forge-config: default.isolate = true
    function test_prod_v3_swapRouter_1pool() public {
        _router("v3-swaprouter-1pool", "prod v3 SwapRouter exactInputSingle 1 pool A->B", _single(TOKEN_A, TOKEN_B, 0), 0, 1, TOKEN_B, 0.99e18);
    }

    /// forge-config: default.isolate = true
    function test_prod_v3_swapRouter_2pools() public {
        bytes memory data = abi.encodeCall(
            ISwapRouter.exactInput,
            (ISwapRouter.ExactInputParams({path: _path(2), recipient: address(this), deadline: type(uint256).max, amountIn: SWAP_AMOUNT, amountOutMinimum: 0}))
        );
        _router("v3-swaprouter-2pools", "prod v3 SwapRouter exactInput 2 pools A->B->C", data, 0, 2, TOKEN_C, 0.98e18);
    }

    /// forge-config: default.isolate = true
    function test_prod_v3_swapRouter_3pools() public {
        bytes memory data = abi.encodeCall(
            ISwapRouter.exactInput,
            (ISwapRouter.ExactInputParams({path: _path(3), recipient: address(this), deadline: type(uint256).max, amountIn: SWAP_AMOUNT, amountOutMinimum: 0}))
        );
        _router("v3-swaprouter-3pools", "prod v3 SwapRouter exactInput 3 pools A->B->C->D", data, 0, 3, TOKEN_D, 0.97e18);
    }

    /// @dev v3 pools hold WETH, so a native-ETH user sends value to the SwapRouter, which
    ///      wraps it in flight (`pay`: tokenIn == WETH9 and the value covers the input).
    /// forge-config: default.isolate = true
    function test_prod_v3_swapRouter_native() public {
        _router("v3-swaprouter-native", "prod v3 SwapRouter exactInputSingle 1 pool ETH(wrapped in flight)->B", _single(WETH, TOKEN_B, SWAP_AMOUNT), SWAP_AMOUNT, 0, TOKEN_B, 0.99e18);
    }

    // ---- minimal router ----

    function _min(uint256 n, string memory name, address tokenOut, uint256 minOut) internal {
        _setup();
        IUniswapV3Pool[] memory pools = new IUniswapV3Pool[](n);
        address[] memory tokensIn = new address[](n);
        pools[0] = poolAB;
        tokensIn[0] = TOKEN_A;
        if (n > 1) {
            pools[1] = poolBC;
            tokensIn[1] = TOKEN_B;
        }
        if (n > 2) {
            pools[2] = poolCD;
            tokensIn[2] = TOKEN_C;
        }
        bytes memory data = abi.encodeCall(minimal.multiHop, (pools, tokensIn, int256(SWAP_AMOUNT), address(this)));
        _call("", address(minimal), 0, data, pools[n - 1], tokenOut);
        uint256 out = _call(name, address(minimal), 0, data, pools[n - 1], tokenOut);
        assertGe(out, minOut, "output sanity");
        _recordCalldata(name, string.concat("v3-minimal-", vm.toString(n), n == 1 ? "pool" : "pools"), data);
    }

    /// forge-config: default.isolate = true
    function test_prod_v3_minimal_1pool() public {
        _min(1, "prod v3 minimal router 1 pool A->B", TOKEN_B, 0.99e18);
    }

    /// forge-config: default.isolate = true
    function test_prod_v3_minimal_2pools() public {
        _min(2, "prod v3 minimal router 2 pools A->B->C", TOKEN_C, 0.98e18);
    }

    /// forge-config: default.isolate = true
    function test_prod_v3_minimal_3pools() public {
        _min(3, "prod v3 minimal router 3 pools A->B->C->D", TOKEN_D, 0.97e18);
    }
}
