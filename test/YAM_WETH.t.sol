// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {YAM_WETH} from "../src/YetAnotherMaximizedWETH.sol";

contract YAM_WETH_Test is Test {
    YAM_WETH weth;

    address mainUser = vm.addr(1);

    address permit2 = vm.addr(0x929829);

    event Transfer(address indexed from, address indexed to, uint amount);
    event Approval(address indexed owner, address indexed spender, uint amount);
    event PrimaryOperatorSet(address indexed account, address indexed prevOperator, address indexed newOperator);

    modifier not0(address _addr) {
        vm.assume(_addr != address(0));
        _;
    }

    modifier notEq(address _a, address _b) {
        vm.assume(_a != _b);
        _;
    }

    function setUp() public {
        weth = new YAM_WETH(permit2);
    }

    function testName() public {
        assertEq(weth.name(), "Yet Another Maximized Wrapped Ether Contract");
    }

    function testSymbol() public {
        assertEq(weth.symbol(), "WETH");
    }

    function testDefaultBalance(address _account) public not0(_account) {
        assertEq(weth.balanceOf(_account), 0);
    }

    function testDeposit(address _account, uint96 _amount) public not0(_account) {
        vm.deal(_account, _amount);
        vm.prank(_account);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), _account, _amount);
        assertTrue(weth.deposit{value: _amount}());
        assertEq(weth.balanceOf(_account), _amount);
    }

    function testSetOperator(
        address _account,
        address _operator1,
        address _operator2,
        uint96 _initialBalance
    ) public not0(_account) {
        setupBalance(_account, _initialBalance);

        vm.prank(_account);
        vm.expectEmit(true, true, true, true);
        emit PrimaryOperatorSet(_account, address(0), _operator1);
        weth.setPrimaryOperator(_operator1);
        assertEq(weth.balanceOf(_account), _initialBalance);
        assertEq(weth.primaryOperatorOf(_account), _operator1);

        vm.prank(_account);
        vm.expectEmit(true, true, true, true);
        emit PrimaryOperatorSet(_account, _operator1, _operator2);
        assertTrue(weth.setPrimaryOperator(_operator2));
        assertEq(weth.balanceOf(_account), _initialBalance);
        assertEq(weth.primaryOperatorOf(_account), _operator2);
    }

    function testTransfer(
        address _from,
        address _to,
        uint96 _fromStartBal,
        uint96 _toStartBal,
        uint96 _transferAmount
    ) public not0(_from) not0(_to) notEq(_from, _to) {
        vm.assume(_transferAmount <= _fromStartBal);
        vm.assume(uint(_fromStartBal) + uint(_toStartBal) <= uint(type(uint96).max));
        setupBalance(_from, _fromStartBal);
        setupBalance(_to, _toStartBal);

        vm.prank(_from);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_from, _to, _transferAmount);
        assertTrue(weth.transfer(_to, _transferAmount));
        assertEq(weth.balanceOf(_from), _fromStartBal - _transferAmount, "from bal mismatch");
        assertEq(weth.balanceOf(_to), _toStartBal + _transferAmount, "to bal mismatch");
    }

    function calldata1() public {
        YAM_WETH.Deposit[] memory deposits = new YAM_WETH.Deposit[](3);
        deposits[0] = YAM_WETH.Deposit(vm.addr(20), 1);
        deposits[1] = YAM_WETH.Deposit(vm.addr(21), 2);
        deposits[2] = YAM_WETH.Deposit(vm.addr(21), 3);
        bytes memory data = abi.encodeCall(YAM_WETH.depositAmountsToMany, (deposits));
        emit log_named_bytes("data", data);
    }

    function setupBalance(address _account, uint96 _balance) internal {
        vm.deal(_account, _balance);
        vm.prank(_account);
        weth.deposit{value: _balance}();
    }

    function setupOperator(address _account, address _operator) internal {
        vm.prank(_account);
        weth.setPrimaryOperator(_operator);
    }
}
