// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {HuffDeployer} from "./utils/HuffDeployer.sol";
import {IMETH} from "../src/interfaces/IMETH.sol";
import {LibString} from "solady/utils/LibString.sol";

/// @author philogy <https://github.com/philogy>
contract METH_WETHTest is Test {
    uint internal constant MAINNET_CHAIN_ID = 0x1;

    IMETH meth;

    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Deposit(address indexed to, uint256 amount);
    event Withdrawal(address indexed from, uint256 amount);

    function setUp() public {
        vm.chainId(MAINNET_CHAIN_ID);

        HuffDeployer huffDeployer = new HuffDeployer();

        uint snapshot = vm.snapshot();
        address nextContractAddr = huffDeployer.deploy("./src/test/Empty.huff", new string[](0), 0);
        vm.revertTo(snapshot);

        string[] memory consts = new string[](1);
        consts[0] = string(
            abi.encodePacked(
                "CACHED_DOMAIN_SEPARATOR=",
                LibString.toHexString(uint(_getDomainSeparator(nextContractAddr)), 32)
            )
        );

        meth = IMETH(huffDeployer.deploy("./src/METH_WETH.huff", consts, 0));
    }

    modifier realAddr(address _a) {
        vm.assume(_a != address(0));
        _;
    }

    function testSymbol() public {
        bytes memory symbolCall = abi.encodeCall(IMETH.symbol, ());
        (bool success, bytes memory ret) = address(meth).staticcall(symbolCall);
        assertTrue(success);
        assertEq(ret.length, 0x60);
        assertEq(_loadWord(ret, 0x20), 0x20);
        assertEq(_loadWord(ret, 0x40), 4);
        assertEq(_loadWord(ret, 0x60), uint(bytes32("METH")));
        string memory symbol = abi.decode(ret, (string));
        assertEq(symbol, "METH");
    }

    function testName() public {
        bytes memory nameCall = abi.encodeCall(IMETH.name, ());
        (bool success, bytes memory ret) = address(meth).staticcall(nameCall);
        assertTrue(success);
        assertEq(ret.length, 0x80);
        assertEq(_loadWord(ret, 0x20), 0x20);
        assertEq(_loadWord(ret, 0x40), 33);
        assertEq(_loadWord(ret, 0x80), uint(bytes32("r")));
        string memory name = abi.decode(ret, (string));
        assertEq(name, "Maximally Efficient Wrapped Ether");
    }

    function testDecimals() public {
        bytes memory decimalsCall = abi.encodeCall(IMETH.decimals, ());
        (bool success, bytes memory ret) = address(meth).staticcall(decimalsCall);
        assertTrue(success);
        assertEq(ret.length, 0x20);
        assertEq(_loadWord(ret, 0x20), 18);
        uint8 decimals = abi.decode(ret, (uint8));
        assertEq(decimals, 18);
    }

    function testDeposit_fuzzing(address _owner, uint128 _x) public realAddr(_owner) {
        vm.deal(_owner, _x);
        vm.prank(_owner);
        vm.expectEmit(true, true, true, true);
        emit Deposit(_owner, _x);
        meth.deposit{value: _x}();
        assertEq(meth.balanceOf(_owner), _x);
        assertEq(meth.nonces(_owner), 0);
    }

    function testDepositTo_fuzzing(address _from, address _to, uint128 _x) public realAddr(_from) realAddr(_to) {
        vm.deal(_from, _x);
        vm.prank(_from);
        vm.expectEmit(true, true, true, true);
        emit Deposit(_to, _x);
        meth.depositTo{value: _x}(_to);
        assertEq(meth.balanceOf(_to), _x);
        assertEq(meth.nonces(_to), 0);
    }

    function testMulticall() public {
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeCall(IMETH.decimals, ());
        calls[1] = abi.encodeCall(IMETH.symbol, ());
        calls[2] = abi.encodeCall(IMETH.name, ());
        bytes[] memory retData = meth.multicall(calls);
        assertEq(retData.length, 3);
        assertEq(retData[0].length, 0x20);
        assertEq(retData[0], abi.encode(uint8(18)));
        assertEq(retData[1].length, 0x60);
        assertEq(retData[1], abi.encode(string("METH")));
        assertEq(retData[2].length, 0x80);
        assertEq(retData[2], abi.encode(string("Maximally Efficient Wrapped Ether")));
    }

    function _loadWord(bytes memory _bytes, uint _offset) internal pure returns (uint word) {
        assembly {
            word := mload(add(_bytes, _offset))
        }
    }

    function _getDomainSeparator(address _weth) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256("Maximally Efficient Wrapped Ether"),
                    keccak256("1.0"),
                    MAINNET_CHAIN_ID,
                    _weth
                )
            );
    }
}
