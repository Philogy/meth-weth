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

    modifier realAddr(address _addr) {
        vm.assume(_addr != address(0));
        vm.assume(_addr != address(weth));
        _;
    }

    modifier not0(address _addr) {
        vm.assume(_addr != address(0));
        _;
    }

    modifier notEq(address _a, address _b) {
        vm.assume(_a != _b);
        _;
    }

    modifier acceptsETH(address _recipient) {
        if (_recipient != address(weth)) {
            (bool success, ) = _recipient.call{value: 1 wei}("");
            vm.assume(success);
        }
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

    function testDefaultBalance(address _account) public realAddr(_account) {
        assertEq(weth.balanceOf(_account), 0);
    }

    function testDefaultAllowance(address _owner, address _spender) public realAddr(_owner) {
        assertEq(weth.allowance(_owner, _spender), 0);
    }

    function testDeposit(address _account, uint96 _amount) public realAddr(_account) {
        vm.deal(_account, _amount);
        vm.prank(_account);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), _account, _amount);
        assertTrue(weth.deposit{value: _amount}());
        assertEq(weth.balanceOf(_account), _amount);
        assertEq(weth.totalSupply(), _amount);
    }

    function testDepositFallback(address _account, uint96 _amount) public realAddr(_account) {
        vm.deal(_account, _amount);
        vm.prank(_account);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), _account, _amount);
        (bool success, bytes memory returnData) = address(weth).call{value: _amount}("");
        assertSucceeded(success, returnData);
        assertEq(weth.balanceOf(_account), _amount);
        assertEq(weth.totalSupply(), _amount);
    }

    function testDepositTo(address _from, address _to, uint96 _amount) public realAddr(_from) not0(_to) {
        vm.deal(_from, _amount);
        vm.prank(_from);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), _to, _amount);
        assertTrue(weth.depositTo{value: _amount}(_to));
        assertEq(weth.balanceOf(_to), _amount);
        if (_from != _to) assertEq(weth.balanceOf(_from), 0);
        assertEq(weth.totalSupply(), _amount);
    }

    function testCannotDepositToZero(address _from, uint96 _amount) public realAddr(_from) {
        vm.deal(_from, _amount);
        vm.prank(_from);
        vm.expectRevert(YAM_WETH.ZeroAddress.selector);
        weth.depositTo{value: _amount}(address(0));
    }

    function testDepositAmount(address _account, uint96 _value, uint96 _depositAmount) public realAddr(_account) {
        vm.assume(_value >= _depositAmount);
        vm.deal(_account, _value);
        vm.prank(_account);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), _account, _depositAmount);
        assertTrue(weth.depositAmount{value: _value}(_depositAmount));
        assertEq(weth.balanceOf(_account), _depositAmount);
        assertEq(address(weth).balance, _value);
        assertEq(weth.totalSupply(), _depositAmount);
    }

    function testDepositAmountTo(
        address _from,
        address _to,
        uint96 _value,
        uint96 _depositAmount
    ) public realAddr(_from) not0(_to) {
        vm.assume(_value >= _depositAmount);
        vm.deal(_from, _value);
        vm.prank(_from);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), _to, _depositAmount);
        assertTrue(weth.depositAmountTo{value: _value}(_to, _depositAmount));
        assertEq(weth.balanceOf(_to), _depositAmount);
        if (_from != _to) assertEq(weth.balanceOf(_from), 0);
        assertEq(address(weth).balance, _value);
        assertEq(weth.totalSupply(), _depositAmount);
    }

    function testWithdraw(
        address _account,
        uint96 _initialWethBalance,
        uint96 _withdrawAmount
    ) public realAddr(_account) acceptsETH(_account) {
        vm.assume(_initialWethBalance >= _withdrawAmount);
        setupBalance(_account, _initialWethBalance);
        uint balBefore = _account.balance;
        vm.prank(_account);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_account, address(0), _withdrawAmount);
        assertTrue(weth.withdraw(_withdrawAmount));
        assertEq(weth.balanceOf(_account), _initialWethBalance - _withdrawAmount);
        assertEq(_account.balance, balBefore + _withdrawAmount);
    }

    function testWithdrawTo(
        address _from,
        address _to,
        uint96 _initialWethBalance,
        uint96 _withdrawAmount
    ) public realAddr(_from) not0(_to) acceptsETH(_to) {
        vm.assume(_initialWethBalance >= _withdrawAmount);
        setupBalance(_from, _initialWethBalance);

        uint wethBalBefore = address(weth).balance;
        uint toBalBefore = _to.balance;

        vm.prank(_from);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_from, address(0), _withdrawAmount);
        assertTrue(weth.withdrawTo(_to, _withdrawAmount));

        assertEq(weth.balanceOf(_from), _initialWethBalance - _withdrawAmount);
        assertEq(_to.balance, toBalBefore + _withdrawAmount);
        assertEq(address(weth).balance, wethBalBefore - _withdrawAmount);
    }

    function testCannotWithdrawInsufficientBalance(
        address _account,
        uint96 _initialWethBalance,
        uint96 _withdrawAmount
    ) public realAddr(_account) {
        vm.assume(_initialWethBalance < _withdrawAmount);
        setupBalance(_account, _initialWethBalance);
        vm.prank(_account);
        vm.expectRevert(YAM_WETH.InsufficientBalance.selector);
        weth.withdraw(_withdrawAmount);
    }

    function testSetOperator(
        address _account,
        address _operator1,
        address _operator2,
        uint96 _initialBalance
    ) public realAddr(_account) {
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

    function testSupplyCap96(address _account, uint _amount) public realAddr(_account) {
        vm.assume(_amount > uint(type(uint96).max));
        vm.deal(_account, _amount);
        vm.prank(_account);
        vm.expectRevert(YAM_WETH.TotalSupplyOverflow.selector);
        weth.deposit{value: _amount}();
    }

    function testTransfer(
        address _from,
        address _to,
        uint96 _fromStartBal,
        uint96 _toStartBal,
        uint96 _transferAmount
    ) public realAddr(_from) not0(_to) {
        vm.assume(_transferAmount <= _fromStartBal);
        vm.assume(uint(_fromStartBal) + uint(_toStartBal) <= type(uint96).max);
        setupBalance(_from, _fromStartBal);
        setupBalance(_to, _toStartBal);

        vm.prank(_from);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_from, _to, _transferAmount);
        assertTrue(weth.transfer(_to, _transferAmount));
        if (_from != _to) {
            assertEq(weth.balanceOf(_from), _fromStartBal - _transferAmount, "from bal mismatch");
            assertEq(weth.balanceOf(_to), _toStartBal + _transferAmount, "to bal mismatch");
        }
    }

    function testCannotTransferToZero(address _from, uint96 _amount) public realAddr(_from) {
        setupBalance(_from, _amount);
        vm.prank(_from);
        vm.expectRevert(YAM_WETH.ZeroAddress.selector);
        weth.transfer(address(0), _amount);
    }

    function testCannotTransferFromToZero(
        address _operator,
        address _from,
        uint96 _amount
    ) public realAddr(_operator) realAddr(_from) notEq(_operator, permit2) {
        setupBalance(_from, _amount);
        setupOperator(_from, _operator);

        vm.prank(_operator);
        vm.expectRevert(YAM_WETH.ZeroAddress.selector);
        weth.transferFrom(_from, address(0), _amount);
    }

    function testCannotTransferFromZero(
        address _operator,
        address _to,
        uint96 _amount
    ) public realAddr(_operator) not0(_to) notEq(_operator, permit2) {
        // ensure supply
        setupBalance(vm.addr(1), 100e18);

        vm.prank(_operator);
        vm.expectRevert(YAM_WETH.ZeroAddress.selector);
        weth.transferFrom(address(0), _to, _amount);
    }

    function testTransferFromAsOperator(
        address _operator,
        address _from,
        address _to,
        uint96 _transferAmount
    ) public realAddr(_operator) realAddr(_from) not0(_to) notEq(_operator, permit2) {
        setupOperator(_from, _operator);
        setupBalance(_from, _transferAmount);

        vm.prank(_operator);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_from, _to, _transferAmount);
        assertTrue(weth.transferFrom(_from, _to, _transferAmount));
        if (_from != _to) assertEq(weth.balanceOf(_from), 0, "from bal mismatch");
        assertEq(weth.balanceOf(_to), _transferAmount, "to bal mismatch");
        assertEq(weth.primaryOperatorOf(_from), _operator);
    }

    function testCannotTransferInsufficientBalance(
        address _from,
        address _to,
        uint96 _fromStartBal,
        uint96 _transferAmount
    ) public realAddr(_from) not0(_to) {
        vm.assume(_fromStartBal < _transferAmount);
        setupBalance(_from, _fromStartBal);
        vm.prank(_from);
        vm.expectRevert(YAM_WETH.InsufficientBalance.selector);
        weth.transfer(_to, _transferAmount);
    }

    function testApprove(address _owner, address _spender, uint _allowance) public realAddr(_owner) {
        vm.prank(_owner);
        vm.expectEmit(true, true, true, true);
        emit Approval(_owner, _spender, _allowance);
        assertTrue(weth.approve(_spender, _allowance));
        assertEq(weth.allowance(_owner, _spender), _allowance);
    }

    function testPreventsDirtyApprove(address _owner, uint _dirtySpender, uint _allowance) public realAddr(_owner) {
        vm.assume(_dirtySpender > type(uint160).max);
        vm.prank(_owner);
        (bool success, bytes memory returnData) = address(weth).call(
            abi.encodeWithSelector(YAM_WETH.approve.selector, _dirtySpender, _allowance)
        );
        assertFalse(success);
        assertEq(returnData, "");
    }

    function testPreventsDirtyAllowance(uint _dirtyOwner, uint _dirtySpender) public {
        vm.assume(_dirtyOwner > type(uint160).max || _dirtySpender > type(uint160).max);
        (bool success, bytes memory returnData) = address(weth).staticcall(
            abi.encodeWithSelector(YAM_WETH.allowance.selector, _dirtyOwner, _dirtySpender)
        );
        assertFalse(success);
        assertEq(returnData, "");
    }

    function testPreventsDirtyTransferFrom(
        address _operator,
        uint _dirtyFrom,
        address _to
    ) public realAddr(_operator) not0(_to) {
        vm.assume(_dirtyFrom > type(uint160).max);
        vm.prank(_operator);
        (bool success, bytes memory returnData) = address(weth).call(
            abi.encodeWithSelector(YAM_WETH.transferFrom.selector, _dirtyFrom, _to, 0)
        );
        assertFalse(success);
        assertEq(returnData, "");
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

    function assertSucceeded(bool _success, bytes memory _returndata) internal {
        assertTrue(_success);
        bool returnedFlag = abi.decode(_returndata, (bool));
        assertTrue(returnedFlag);
    }
}
