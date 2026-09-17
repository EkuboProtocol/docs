// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

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

/// @notice Minimal N-hop exact-input router over v3 pools with the same token flow as
///         the production SwapRouter's `exactInput`: the first hop is paid straight from
///         the user (transferFrom user -> pool), intermediate outputs land on the router
///         and are paid forward (transfer router -> next pool), and the last hop delivers
///         to the recipient. That is 2 transfers per pool, and every intermediate router
///         balance goes 0 -> x -> 0 inside the transaction (refund-eligible, see tests).
contract V3MultiHopRouter {
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
        if (payer == address(this)) SharedToken(tokenIn).transfer(msg.sender, owed);
        else SharedToken(tokenIn).transferFrom(payer, msg.sender, owed);
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
    uint128 constant LIQUIDITY = 998501199320305883812938; // liquidity for 1M/1M full-range at the init price (matches the v4/ekubo harnesses)
    int256 constant SWAP_AMOUNT = 1e18; // exact input

    function setUp() public virtual {
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

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata) external {
        if (amount0Owed > 0) SharedToken(IUniswapV3Pool(msg.sender).token0()).transfer(msg.sender, amount0Owed);
        if (amount1Owed > 0) SharedToken(IUniswapV3Pool(msg.sender).token1()).transfer(msg.sender, amount1Owed);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        if (amount0Delta > 0) SharedToken(IUniswapV3Pool(msg.sender).token0()).transfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) SharedToken(IUniswapV3Pool(msg.sender).token1()).transfer(msg.sender, uint256(amount1Delta));
    }

    function _pools(uint256 n) internal view returns (IUniswapV3Pool[] memory pools, address[] memory tokensIn) {
        pools = new IUniswapV3Pool[](n);
        tokensIn = new address[](n);
        pools[0] = poolAB;
        tokensIn[0] = address(tokenA);
        if (n > 1) {
            pools[1] = poolBC;
            tokensIn[1] = address(tokenB);
        }
        if (n > 2) {
            pools[2] = poolCD;
            tokensIn[2] = address(tokenC);
        }
    }

    /// @dev Isolated calls get their own EVM context, so `snapshotGasLastCall` reports the
    ///      call's execution gas net of the EIP-3529 refund (capped at 1/5 of gas used),
    ///      excluding the 21,000 base and calldata. The gross figure before refunds and the
    ///      refund actually granted are recorded alongside.
    function _snapshotWithRefund(string memory name) internal {
        Vm.Gas memory g = vm.lastCallGas();
        vm.snapshotGasLastCall(name);
        vm.snapshotValue(string.concat(name, " gross before refund"), g.gasTotalUsed);
        vm.snapshotValue(string.concat(name, " refund granted"), uint256(uint64(g.gasRefunded)));
    }

    // ---- single swaps: direct pool call, the test contract is the callback payer ----
    // A lower bound only: an externally owned account cannot be a v3 callback payer, so
    // the cheapest path a user can actually send is the 1-pool route below. The callback
    // runs in this test contract, so these direct-call figures move by a few gas when the
    // contract's function set (its dispatcher) changes.

    /// forge-config: default.isolate = true
    function test_gas_single_steady_erc20() public {
        poolAB.swap(address(this), true, SWAP_AMOUNT, MIN_LIMIT, ""); // warm-up, unmeasured
        poolAB.swap(address(this), true, SWAP_AMOUNT, MIN_LIMIT, "");
        _snapshotWithRefund("v3 single erc20 steady-state");
    }

    /// forge-config: default.isolate = true
    function test_gas_single_steady_erc20_reverse() public {
        poolAB.swap(address(this), false, SWAP_AMOUNT, MAX_LIMIT, "");
        poolAB.swap(address(this), false, SWAP_AMOUNT, MAX_LIMIT, "");
        _snapshotWithRefund("v3 single erc20 reverse steady-state");
    }

    /// @dev The oracle observation is written only by swaps that change the tick, and at
    ///      most once per block (`Oracle.write` returns early on a repeated timestamp). Two
    ///      tests with identical swaps isolate that write. Warm-ups: one reverse swap (so the
    ///      token1 fee accumulator is already nonzero) and one forward swap (tick 30 -> 29);
    ///      the measured swap buys 2 tokens back (tick 29 -> 30), once in the same block
    ///      (write skipped) and once in a later block (observation written, cardinality 1).
    function _tickChangeWarmUp() internal {
        poolAB.swap(address(this), false, SWAP_AMOUNT, MAX_LIMIT, "");
        poolAB.swap(address(this), true, SWAP_AMOUNT, MIN_LIMIT, "");
    }

    /// forge-config: default.isolate = true
    function test_gas_single_tickChange_sameBlock() public {
        _tickChangeWarmUp();
        poolAB.swap(address(this), false, 2 * SWAP_AMOUNT, MAX_LIMIT, "");
        _snapshotWithRefund("v3 single tick-changing swap same block (oracle write skipped)");
    }

    /// forge-config: default.isolate = true
    function test_gas_single_tickChange_nextBlock() public {
        _tickChangeWarmUp();
        vm.warp(block.timestamp + 12);
        vm.roll(block.number + 1);
        poolAB.swap(address(this), false, 2 * SWAP_AMOUNT, MAX_LIMIT, "");
        _snapshotWithRefund("v3 single tick-changing swap next block (oracle written)");
    }

    /// @dev No warm-up: the very first swap in a freshly capitalized pool, which writes the
    ///      fee-growth accumulator from zero (SSTORE 20,000 instead of 2,900).
    /// forge-config: default.isolate = true
    function test_gas_single_firstSwap_erc20() public {
        poolAB.swap(address(this), true, SWAP_AMOUNT, MIN_LIMIT, "");
        _snapshotWithRefund("v3 single erc20 first swap in fresh pool");
    }

    // ---- routes through the SwapRouter-shaped minimal router, warmed ----

    /// forge-config: default.isolate = true
    function test_gas_route_1pool() public {
        (IUniswapV3Pool[] memory pools, address[] memory tokensIn) = _pools(1);
        multihopRouter.multiHop(pools, tokensIn, SWAP_AMOUNT, address(this));
        multihopRouter.multiHop(pools, tokensIn, SWAP_AMOUNT, address(this));
        _snapshotWithRefund("v3 route 1 pool steady-state");
    }

    /// forge-config: default.isolate = true
    function test_gas_route_2pools() public {
        (IUniswapV3Pool[] memory pools, address[] memory tokensIn) = _pools(2);
        multihopRouter.multiHop(pools, tokensIn, SWAP_AMOUNT, address(this));
        multihopRouter.multiHop(pools, tokensIn, SWAP_AMOUNT, address(this));
        _snapshotWithRefund("v3 route 2 pools steady-state");
    }

    /// forge-config: default.isolate = true
    function test_gas_route_3pools() public {
        (IUniswapV3Pool[] memory pools, address[] memory tokensIn) = _pools(3);
        multihopRouter.multiHop(pools, tokensIn, SWAP_AMOUNT, address(this));
        multihopRouter.multiHop(pools, tokensIn, SWAP_AMOUNT, address(this));
        _snapshotWithRefund("v3 route 3 pools steady-state");
    }

    // ---- liquidity provision, direct to the pool ----

    /// @dev Warm-up mint to one owner, measured mint to a different owner: a brand-new
    ///      position (fresh position slots) with both boundary ticks already initialized,
    ///      the same shape as the Ekubo and v4 new-position mints.
    /// forge-config: default.isolate = true
    function test_gas_mint_newPosition() public {
        poolAB.mint(address(this), TICK_LOWER, TICK_UPPER, LIQUIDITY, "");
        poolAB.mint(address(0xBEEF), TICK_LOWER, TICK_UPPER, LIQUIDITY, "");
        _snapshotWithRefund("v3 mint new position");
    }

    /// @dev Adding liquidity to an existing position (same owner and ticks): cheaper, because
    ///      the position slots are already nonzero.
    /// forge-config: default.isolate = true
    function test_gas_mint_samePosition() public {
        poolAB.mint(address(this), TICK_LOWER, TICK_UPPER, LIQUIDITY, "");
        poolAB.mint(address(this), TICK_LOWER, TICK_UPPER, LIQUIDITY, "");
        _snapshotWithRefund("v3 mint same position");
    }

    // ---- pool creation ----

    /// @dev v3 pools are separate contracts: `createPool` deploys one (CREATE2 of the full
    ///      pool bytecode), then `initialize` sets the price and the first observation.
    /// forge-config: default.isolate = true
    function test_gas_initializePool() public {
        IUniswapV3Pool poolAD = IUniswapV3Pool(factory.createPool(address(tokenA), address(tokenD), 3000));
        uint256 create = vm.snapshotGasLastCall("v3 createPool");
        poolAD.initialize(INIT_SQRT_PRICE);
        uint256 init = vm.snapshotGasLastCall("v3 initialize");
        vm.snapshotValue("v3 createPool + initialize", create + init);
    }
}
