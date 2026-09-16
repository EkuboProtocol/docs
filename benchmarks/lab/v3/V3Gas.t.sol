// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {Test} from "forge-std/Test.sol";

interface IUniswapV3Factory {
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
}

interface IUniswapV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function initialize(uint160 sqrtPriceX96) external;
    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount, bytes calldata data)
        external
        returns (uint256 amount0, uint256 amount1);
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

/// @notice Interface to the shared token artifact (solmate MockERC20 bytecode,
///         deployed via deployCode): the identical token contract runs in all harnesses.
interface SharedToken {
    function mint(address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Minimal N-hop exact-input router over v3 pools. One `multiHop` call covers
///         every hop plus settlement, so the gas snapshot captures the full route cost,
///         comparable to a production SwapRouter-style exact-input path.
contract V3MultiHopRouter {
    uint160 constant MIN_LIMIT = 4295128740; // MIN_SQRT_RATIO + 1

    function multiHop(IUniswapV3Pool[] memory pools, int256 amountIn, address recipient)
        external
        returns (int256 out)
    {
        SharedToken(pools[0].token0()).transferFrom(msg.sender, address(this), uint256(amountIn));
        int256 amount = amountIn;
        for (uint256 i = 0; i < pools.length; i++) {
            (, int256 a1) = pools[i].swap(address(this), true, amount, MIN_LIMIT, "");
            amount = -a1;
            require(amount > 0, "no hop output");
        }
        out = amount;
        SharedToken(pools[pools.length - 1].token1()).transfer(recipient, uint256(out));
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        if (amount0Delta > 0) SharedToken(IUniswapV3Pool(msg.sender).token0()).transfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) SharedToken(IUniswapV3Pool(msg.sender).token1()).transfer(msg.sender, uint256(amount1Delta));
    }
}

/// @notice Uniswap v3 gas harness deploying canonical mainnet bytecode (v3-core 1.0.1
///         artifacts) and driving it with a minimal callback payer. Direct pool calls
///         make the single-hop number a lower bound for production-router (SwapRouter) gas.
contract V3GasTest is Test {
    IUniswapV3Factory factory;
    IUniswapV3Pool poolAB;
    IUniswapV3Pool poolBC;
    IUniswapV3Pool poolCD;
    V3MultiHopRouter multihopRouter;

    SharedToken tokenA;
    SharedToken tokenB;
    SharedToken tokenC;
    SharedToken tokenD;

    int24 constant TICK_LOWER = -887220;
    int24 constant TICK_UPPER = 887220;
    uint160 constant INIT_SQRT_PRICE = 79347087983665984109010747392; // 1.0001**(30/2) * 2**96: tick 30, strictly inside (spacing 60)
    uint160 constant MIN_LIMIT = 4295128740; // MIN_SQRT_RATIO + 1
    uint160 constant MAX_LIMIT = 1461446703485210103287273052203988822378723970341; // MAX_SQRT_RATIO - 1
    uint128 constant LIQUIDITY = 1e30;
    int256 constant SWAP_AMOUNT = 1e18; // exact input

    function setUp() public {
        factory = IUniswapV3Factory(vm.deployCode("artifacts/UniswapV3Factory.json"));

        // One identical token artifact (solmate MockERC20) in every harness.
        tokenA = SharedToken(vm.deployCode("artifacts/MockERC20.json", abi.encode("TokenA", "A", 18)));
        tokenB = SharedToken(vm.deployCode("artifacts/MockERC20.json", abi.encode("TokenB", "B", 18)));
        tokenC = SharedToken(vm.deployCode("artifacts/MockERC20.json", abi.encode("TokenC", "C", 18)));
        tokenD = SharedToken(vm.deployCode("artifacts/MockERC20.json", abi.encode("TokenD", "D", 18)));
        if (address(tokenA) > address(tokenB)) (tokenA, tokenB) = (tokenB, tokenA);
        if (address(tokenC) > address(tokenD)) (tokenC, tokenD) = (tokenD, tokenC);
        if (address(tokenB) > address(tokenC)) (tokenB, tokenC) = (tokenC, tokenB);
        if (address(tokenA) > address(tokenB)) (tokenA, tokenB) = (tokenB, tokenA);
        if (address(tokenC) > address(tokenD)) (tokenC, tokenD) = (tokenD, tokenC);
        tokenA.mint(address(this), 1e45);
        tokenB.mint(address(this), 1e45);
        tokenC.mint(address(this), 1e45);
        tokenD.mint(address(this), 1e45);

        poolAB = IUniswapV3Pool(factory.createPool(address(tokenA), address(tokenB), 3000));
        poolBC = IUniswapV3Pool(factory.createPool(address(tokenB), address(tokenC), 3000));
        poolCD = IUniswapV3Pool(factory.createPool(address(tokenC), address(tokenD), 3000));
        poolAB.initialize(INIT_SQRT_PRICE);
        poolBC.initialize(INIT_SQRT_PRICE);
        poolCD.initialize(INIT_SQRT_PRICE);
        poolAB.mint(address(this), TICK_LOWER, TICK_UPPER, LIQUIDITY, "");
        poolBC.mint(address(this), TICK_LOWER, TICK_UPPER, LIQUIDITY, "");
        poolCD.mint(address(this), TICK_LOWER, TICK_UPPER, LIQUIDITY, "");
        multihopRouter = new V3MultiHopRouter();
        tokenA.approve(address(multihopRouter), type(uint256).max);
    }

    function _tokenFor(address pool, bool isToken0) internal view returns (SharedToken) {
        if (pool == address(poolAB)) return isToken0 ? tokenA : tokenB;
        if (pool == address(poolBC)) return isToken0 ? tokenB : tokenC;
        return isToken0 ? tokenC : tokenD;
    }

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata) external {
        if (amount0Owed > 0) SharedToken(IUniswapV3Pool(msg.sender).token0()).transfer(msg.sender, amount0Owed);
        if (amount1Owed > 0) SharedToken(IUniswapV3Pool(msg.sender).token1()).transfer(msg.sender, amount1Owed);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        if (amount0Delta > 0) SharedToken(IUniswapV3Pool(msg.sender).token0()).transfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) SharedToken(IUniswapV3Pool(msg.sender).token1()).transfer(msg.sender, uint256(amount1Delta));
    }

    function _coolAll() internal {
        vm.cool(address(factory));
        vm.cool(address(poolAB));
        vm.cool(address(poolBC));
        vm.cool(address(poolCD));
        vm.cool(address(multihopRouter));
        vm.cool(address(tokenA));
        vm.cool(address(tokenB));
        vm.cool(address(tokenC));
        vm.cool(address(tokenD));
        vm.cool(address(this));
    }

    /// forge-config: default.isolate = true
    function test_gas_single_exactInput_erc20() public {
        _coolAll();
        poolAB.swap(address(this), true, SWAP_AMOUNT, MIN_LIMIT, "");
        vm.snapshotGasLastCall("v3 single exact-input token0->token1 wide-range");
    }

    /// forge-config: default.isolate = true
    function test_gas_single_exactInput_erc20_reverse() public {
        _coolAll();
        poolAB.swap(address(this), false, SWAP_AMOUNT, MAX_LIMIT, "");
        vm.snapshotGasLastCall("v3 single exact-input token1->token0 wide-range");
    }

    /// forge-config: default.isolate = true
    function test_gas_oneHop_routerPath() public {
        IUniswapV3Pool[] memory pools = new IUniswapV3Pool[](1);
        pools[0] = poolAB;
        _coolAll();
        multihopRouter.multiHop(pools, SWAP_AMOUNT, address(this));
        vm.snapshotGasLastCall("v3 one-hop exact-input router path");
    }

    /// forge-config: default.isolate = true
    function test_gas_twoHop_exactInput() public {
        IUniswapV3Pool[] memory pools = new IUniswapV3Pool[](2);
        pools[0] = poolAB;
        pools[1] = poolBC;
        _coolAll();
        multihopRouter.multiHop(pools, SWAP_AMOUNT, address(this));
        vm.snapshotGasLastCall("v3 two-hop exact-input two pools");
    }

    /// forge-config: default.isolate = true
    function test_gas_threeHop_exactInput() public {
        IUniswapV3Pool[] memory pools = new IUniswapV3Pool[](3);
        pools[0] = poolAB;
        pools[1] = poolBC;
        pools[2] = poolCD;
        _coolAll();
        multihopRouter.multiHop(pools, SWAP_AMOUNT, address(this));
        vm.snapshotGasLastCall("v3 three-hop exact-input three pools");
    }

    /// forge-config: default.isolate = true
    function test_gas_mint_fullRange() public {
        _coolAll();
        // second position on the existing pool: same tier as the other harnesses'
        // subsequent mints (no pool/tick initialization in the measured call)
        poolAB.mint(address(this), TICK_LOWER, TICK_UPPER, LIQUIDITY, "");
        vm.snapshotGasLastCall("v3 mint wide-range position");
    }
}
