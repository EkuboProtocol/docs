// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import {Test} from "forge-std/Test.sol";

interface IFreshToken {
    function mint(address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

/// @notice Shared fixture for the production-contract benches: four fresh ERC20 tokens
///         (the same solmate MockERC20 artifact as the lab harnesses) etched at fixed,
///         address-ordered, all-nonzero-byte addresses on a fork of the latest block, so
///         every run is reproducible without a block pin and the SDK-generated router
///         calldata can embed the token addresses. Nothing in this file is measured.
abstract contract ProdCommon is Test {
    // Ordered A < B < C < D. All bytes nonzero, so calldata that carries these addresses
    // pays the same 16 gas per byte as a real token address would (a real address has
    // about one zero byte in 256; these have none, which is marginally pessimistic).
    address constant TOKEN_A = 0x1111111111111111111111111111111111111111;
    address constant TOKEN_B = 0x2222222222222222222222222222222222222222;
    address constant TOKEN_C = 0x3333333333333333333333333333333333333333;
    address constant TOKEN_D = 0x4444444444444444444444444444444444444444;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 constant LIQ_AMOUNT = 1_000_000 ether; // per side, per pool
    uint256 constant SWAP_AMOUNT = 1 ether; // exact input, every measured swap

    function _deployTokens() internal {
        address[4] memory ts = [TOKEN_A, TOKEN_B, TOKEN_C, TOKEN_D];
        string[4] memory names = ["TokenA", "TokenB", "TokenC", "TokenD"];
        string[4] memory syms = ["A", "B", "C", "D"];
        for (uint256 i = 0; i < 4; i++) {
            assertEq(ts[i].code.length, 0, "fresh token address already has code on this chain");
            deployCodeTo("artifacts/MockERC20.json", abi.encode(names[i], syms[i], uint8(18)), ts[i]);
            IFreshToken(ts[i]).mint(address(this), 10_000_000 ether);
        }
        vm.deal(address(this), 10_000_000 ether);
        vm.snapshotValue("prod fork block number", block.number);
        vm.snapshotValue("prod fork block timestamp", block.timestamp);
    }

    /// @dev Records the exact bytes of a measured call next to its gas: byte count, the
    ///      EIP-2028 calldata gas (4 per zero byte, 16 per nonzero byte) and the EIP-7623
    ///      floor tokens, so the page can add calldata to execution gas without modeling.
    function _recordCalldata(string memory name, string memory file, bytes memory data) internal {
        uint256 zeros;
        for (uint256 i = 0; i < data.length; i++) {
            if (data[i] == 0) zeros++;
        }
        uint256 nonzeros = data.length - zeros;
        vm.snapshotValue(string.concat(name, " | calldata bytes"), data.length);
        vm.snapshotValue(string.concat(name, " | calldata gas (4/16 per byte)"), 4 * zeros + 16 * nonzeros);
        vm.snapshotValue(string.concat(name, " | calldata floor gas (EIP-7623, 10 per token)"), 10 * (zeros + 4 * nonzeros));
        vm.writeFile(string.concat("calldata/", file, ".hex"), vm.toString(data));
    }

    receive() external payable {}
}
