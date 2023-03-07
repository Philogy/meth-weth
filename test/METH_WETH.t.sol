// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {HuffDeployer} from "./utils/HuffDeployer.sol";
import {IMETH} from "../src/interfaces/IMETH.sol";
import {LibString} from "solady/utils/LibString.sol";

/// @author philogy <https://github.com/philogy>
contract METH_WETHTest is Test {
    uint256 internal constant MAINNET_CHAIN_ID = 0x1;

    address internal recovery = makeAddr("RECOVERY_ADDR");

    IMETH meth;

    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Deposit(address indexed to, uint256 amount);
    event Withdrawal(address indexed from, uint256 amount);

    function setUp() public {
        vm.chainId(MAINNET_CHAIN_ID);

        HuffDeployer huffDeployer = new HuffDeployer();

        string[] memory consts = new string[](1);
        consts[0] = string(abi.encodePacked("RECOVERY_ADDR=", LibString.toHexString(recovery)));

        meth = IMETH(huffDeployer.deploy("./src/METH_WETH.huff", consts, 0));
    }

    modifier realAddr(address _a) {
        vm.assume(_a != address(0));
        _;
    }

    function testSymbol() public {
        emit log_named_uint("address(meth).code.length", address(meth).code.length);
        bytes memory symbolCall = abi.encodeCall(IMETH.symbol, ());
        (bool success, bytes memory ret) = address(meth).staticcall(symbolCall);
        assertTrue(success);
        assertEq(ret.length, 0x60);
        assertEq(_loadWord(ret, 0x20), 0x20);
        assertEq(_loadWord(ret, 0x40), 4);
        assertEq(_loadWord(ret, 0x60), uint256(bytes32("METH")));
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
        assertEq(_loadWord(ret, 0x80), uint256(bytes32("r")));
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

    function test_fuzzingDeposit(address _owner, uint128 _x) public {
        vm.deal(_owner, _x);
        vm.prank(_owner);
        vm.expectEmit(true, true, true, true);
        emit Deposit(_owner, _x);
        meth.deposit{value: _x}();
        assertEq(meth.balanceOf(_owner), _x);
        assertEq(meth.nonces(_owner), 0);
    }

    function test_fuzzingDepositTo(address _from, address _to, uint128 _x) public {
        vm.deal(_from, _x);
        vm.prank(_from);
        vm.expectEmit(true, true, true, true);
        emit Deposit(_to, _x);
        meth.depositTo{value: _x}(_to);
        assertEq(meth.balanceOf(_to), _x);
        assertEq(meth.nonces(_to), 0);
    }

    function test_fuzzingTransfer(
        address _from,
        address _to,
        uint128 _startAmount,
        uint128 _transferAmount,
        uint128 _fromNonce,
        uint128 _toNonce
    ) public {
        vm.assume(_startAmount >= _transferAmount);
        _setNonce(_from, _fromNonce);
        _setNonce(_to, _toNonce);

        vm.deal(_from, _startAmount);
        vm.prank(_from);
        meth.deposit{value: _startAmount}();

        vm.prank(_from);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_from, _to, _transferAmount);
        assertTrue(meth.transfer(_to, _transferAmount));

        if (_from != _to) {
            assertEq(meth.nonces(_from), _fromNonce, "transfer changed from nonce");
            assertEq(meth.balanceOf(_from), _startAmount - _transferAmount, "balance from after");
            assertEq(meth.balanceOf(_to), _transferAmount, "balance to after");
        }
        assertEq(meth.nonces(_to), _toNonce, "transfer changed to nonce");
    }

    function test_fuzzingApprove(address _owner, address _spender, uint256 _allowance1, uint256 _allowance2) public {
        assertEq(meth.allowance(_owner, _spender), 0);

        vm.prank(_owner);
        vm.expectEmit(true, true, true, true);
        emit Approval(_owner, _spender, _allowance1);
        meth.approve(_spender, _allowance1);
        assertEq(meth.allowance(_owner, _spender), _allowance1);

        vm.prank(_owner);
        vm.expectEmit(true, true, true, true);
        emit Approval(_owner, _spender, _allowance2);
        meth.approve(_spender, _allowance2);
        assertEq(meth.allowance(_owner, _spender), _allowance2);
    }

    function test_fuzzingTransferFrom(
        address _operator,
        address _from,
        address _to,
        uint256 _allowance,
        uint128 _startAmount,
        uint128 _transferAmount,
        uint128 _fromNonce,
        uint128 _toNonce
    ) public {
        vm.assume(0xff00000000000000000000000000000000000000000000000000000000000000 >= _allowance);
        vm.assume(_allowance >= _startAmount);
        vm.assume(_startAmount >= _transferAmount);

        // Setup.
        _setNonce(_from, _fromNonce);
        _setNonce(_to, _toNonce);
        vm.deal(_from, _startAmount);
        vm.prank(_from);
        meth.deposit{value: _startAmount}();
        vm.prank(_from);
        meth.approve(_operator, _allowance);

        // Actual test.
        vm.prank(_operator);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_from, _to, _transferAmount);
        bool success = meth.transferFrom(_from, _to, _transferAmount);
        assertTrue(success);

        assertEq(meth.allowance(_from, _operator), _allowance - _transferAmount);
        assertEq(meth.nonces(_from), _fromNonce);
        assertEq(meth.nonces(_to), _toNonce);
        if (_from != _to) {
            assertEq(meth.balanceOf(_from), _startAmount - _transferAmount);
            assertEq(meth.balanceOf(_to), _transferAmount);
        } else {
            assertEq(meth.balanceOf(_from), _startAmount);
        }
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

    function test_fuzzing_util_setNonce(address _account, uint128 _nonce) public {
        _setNonce(_account, _nonce);
        assertEq(meth.nonces(_account), _nonce);
    }

    function testRecovery() public {
        address user = vm.addr(1);
        vm.deal(user, 3 ether);
        vm.prank(user);
        meth.depositTo{value: 2.5 ether}(address(0));
        assertEq(meth.balanceOf(address(0)), 2.5 ether);
        vm.prank(user);
        meth.depositTo{value: 0.3 ether}(address(meth));
        assertEq(meth.balanceOf(address(meth)), 0.3 ether);
        meth.rescueLost();
        assertEq(meth.balanceOf(recovery), 2.8 ether);
    }

    function testDomainSeparator() public {
        assertEq(meth.DOMAIN_SEPARATOR(), _getDomainSeparator(address(meth)));
    }

    function _setNonce(address _account, uint128 _nonce) internal {
        bytes32 accSlot = bytes32(uint256(uint160(_account)));
        bytes32 slotContent = vm.load(address(meth), accSlot);
        vm.store(address(meth), accSlot, bytes32((uint256(_nonce) << 128) | uint256(uint160(uint256(slotContent)))));
    }

    function _loadWord(bytes memory _bytes, uint256 _offset) internal pure returns (uint256 word) {
        assembly {
            word := mload(add(_bytes, _offset))
        }
    }

    function _getDomainSeparator(address _weth) internal pure returns (bytes32) {
        return keccak256(
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
