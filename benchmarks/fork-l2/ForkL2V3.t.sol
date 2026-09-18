// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {Test, Vm} from "forge-std/Test.sol";

/// Classic SwapRouter (Arbitrum One, same contract and address as mainnet): params carry a deadline.
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

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

/// SwapRouter02 (the only Uniswap-listed v3 router on Base): no deadline field.
interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

interface IUniswapV3PoolLike {
    function slot0()
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint16, uint16, uint16, uint8, bool);
    function liquidity() external view returns (uint128);
    function fee() external view returns (uint24);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

/// @notice L2-fork measurement: the deployed Uniswap v3 router + the deepest live WETH/USDC
///         pool on the chain, USDC exact-input to WETH, warmed with one identical unmeasured
///         swap; every call isolated, snapshot = execution gas of the measured call (net of
///         refunds, excluding the 21,000 base and calldata). Ticks are read from `slot0` and
///         cross-checked against the pool's `Swap` event.
abstract contract ForkL2V3Base is Test {
    bytes32 constant SWAP_TOPIC = keccak256("Swap(address,address,int256,int256,uint160,uint128,int24)");

    struct Cfg {
        string name;
        uint256 chainId;
        uint256 blockNumber;
        uint256 timestamp;
        address router;
        bool classic; // true: SwapRouter (deadline); false: SwapRouter02
        address pool;
        address weth;
        address usdc;
        uint24 fee;
    }

    function _cfg() internal pure virtual returns (Cfg memory);

    function _setup() internal {
        Cfg memory c = _cfg();
        assertEq(block.chainid, c.chainId, "chain id");
        // Arbitrum forks report the L1 block number as `block.number`; the timestamp pins the block on both chains.
        assertEq(block.timestamp, c.timestamp, "pinned block timestamp");
        assertGt(c.router.code.length, 0, "router deployed");
        assertEq(IUniswapV3PoolLike(c.pool).token0(), c.weth);
        assertEq(IUniswapV3PoolLike(c.pool).token1(), c.usdc);
        assertEq(IUniswapV3PoolLike(c.pool).fee(), c.fee);
        vm.snapshotValue(string.concat("fork-l2 ", c.name, " v3 pool liquidity"), IUniswapV3PoolLike(c.pool).liquidity());
        deal(c.usdc, address(this), 1_000_000_000_000); // 1e6 USDC
        IERC20Like(c.usdc).approve(c.router, type(uint256).max);
        assertEq(IERC20Like(c.usdc).allowance(address(this), c.router), type(uint256).max, "max approval");
    }

    function _calldata(uint256 amountIn) internal view returns (bytes memory) {
        Cfg memory c = _cfg();
        if (c.classic) {
            return abi.encodeCall(
                ISwapRouter.exactInputSingle,
                (
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: c.usdc,
                        tokenOut: c.weth,
                        fee: c.fee,
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountIn: amountIn,
                        amountOutMinimum: 0,
                        sqrtPriceLimitX96: 0
                    })
                )
            );
        }
        return abi.encodeCall(
            ISwapRouter02.exactInputSingle,
            (
                ISwapRouter02.ExactInputSingleParams({
                    tokenIn: c.usdc,
                    tokenOut: c.weth,
                    fee: c.fee,
                    recipient: address(this),
                    amountIn: amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            )
        );
    }

    function _swap(uint256 amountIn, string memory snapshotName) internal returns (uint256 out, bytes memory cd) {
        Cfg memory c = _cfg();
        cd = _calldata(amountIn);
        (, int24 tickBefore,,,,,) = IUniswapV3PoolLike(c.pool).slot0();
        uint256 wethBefore = IERC20Like(c.weth).balanceOf(address(this));
        vm.recordLogs();
        (bool ok, bytes memory ret) = c.router.call(cd);
        if (bytes(snapshotName).length > 0) vm.snapshotGasLastCall(snapshotName);
        assertTrue(ok, "swap");
        out = abi.decode(ret, (uint256));
        assertEq(IERC20Like(c.weth).balanceOf(address(this)) - wethBefore, out, "output delivered");
        (, int24 tickAfter,,,,,) = IUniswapV3PoolLike(c.pool).slot0();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool seen;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == c.pool && logs[i].topics[0] == SWAP_TOPIC) {
                (,,,, int24 eventTick) = abi.decode(logs[i].data, (int256, int256, uint160, uint128, int24));
                assertEq(eventTick, tickAfter, "Swap event tick equals slot0 tick");
                seen = true;
            }
        }
        assertTrue(seen, "Swap event found");
        if (bytes(snapshotName).length > 0) {
            emit log_named_int("v3 tick before", tickBefore);
            emit log_named_int("v3 tick after", tickAfter);
            int256 moved = int256(tickAfter) - int256(tickBefore);
            vm.snapshotValue(string.concat(snapshotName, " | ticks moved"), uint256(moved < 0 ? -moved : moved));
        }
    }

    function _run(uint256 usdc, uint256 minOut, uint256 maxOut) internal {
        _setup();
        Cfg memory c = _cfg();
        _swap(usdc, ""); // warm-up, unmeasured
        assertGt(IERC20Like(c.weth).balanceOf(address(this)), 0, "recipient WETH balance nonzero before measured swap");
        string memory size = vm.toString(usdc / 1_000_000);
        string memory routerName = c.classic ? "SwapRouter" : "SwapRouter02";
        string memory name = string.concat(
            "fork-l2 ", c.name, " v3 ", routerName, " ", size, " USDC->WETH fee-", vm.toString(uint256(c.fee))
        );
        (uint256 out, bytes memory cd) = _swap(usdc, name);
        vm.snapshotValue(string.concat("fork-l2 ", c.name, " v3 ", routerName, " output ", size, " USDC->WETH (wei)"), out);
        vm.snapshotValue(string.concat("fork-l2 ", c.name, " v3 ", routerName, " calldata bytes ", size, " USDC"), cd.length);
        vm.writeFile(string.concat("calldata/v3-", routerName, "-", c.name, "-", size, ".hex"), vm.toString(cd));
        emit log_named_uint("v3 measured output (WETH wei)", out);
        assertGe(out, minOut);
        assertLe(out, maxOut);
    }

    /// forge-config: default.isolate = true
    function test_fork_l2_v3_exactInputSingle_1000() public {
        _run(1_000_000_000, 0.38 ether, 0.43 ether);
    }

    /// forge-config: default.isolate = true
    function test_fork_l2_v3_exactInputSingle_100() public {
        _run(100_000_000, 0.038 ether, 0.043 ether);
    }

    /// forge-config: default.isolate = true
    function test_fork_l2_v3_exactInputSingle_50() public {
        _run(50_000_000, 0.019 ether, 0.0215 ether);
    }
}

/// Run with: --fork-url <base-archive-rpc> --fork-block-number 51439900
contract ForkL2V3BaseTest is ForkL2V3Base {
    function _cfg() internal pure override returns (Cfg memory) {
        return Cfg({
            name: "base",
            chainId: 8453,
            blockNumber: 51439900,
            timestamp: 1789669147,
            router: 0x2626664c2603336E57B271c5C0b26F421741e481, // SwapRouter02 (docs.uniswap.org Base deployments)
            classic: false,
            pool: 0x6c561B446416E1A00E8E93E221854d6eA4171372, // WETH/USDC fee 3000, deepest of 100/500/3000/10000
            weth: 0x4200000000000000000000000000000000000006,
            usdc: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
            fee: 3000
        });
    }
}

/// Run with: --fork-url <arbitrum-archive-rpc> --fork-block-number 506178800
contract ForkL2V3ArbitrumTest is ForkL2V3Base {
    function _cfg() internal pure override returns (Cfg memory) {
        return Cfg({
            name: "arbitrum",
            chainId: 42161,
            blockNumber: 506178800,
            timestamp: 1789669181,
            router: 0xE592427A0AEce92De3Edee1F18E0157C05861564, // classic SwapRouter (same as mainnet)
            classic: true,
            pool: 0xC6962004f452bE9203591991D15f6b388e09E8D0, // WETH/USDC fee 500, deepest of 100/500/3000/10000
            weth: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            usdc: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            fee: 500
        });
    }
}

/// Same pool through SwapRouter02, for a like-for-like router with the Base leg.
contract ForkL2V3ArbitrumRouter02Test is ForkL2V3Base {
    function _cfg() internal pure override returns (Cfg memory) {
        return Cfg({
            name: "arbitrum",
            chainId: 42161,
            blockNumber: 506178800,
            timestamp: 1789669181,
            router: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45, // SwapRouter02
            classic: false,
            pool: 0xC6962004f452bE9203591991D15f6b388e09E8D0,
            weth: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            usdc: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            fee: 500
        });
    }
}
