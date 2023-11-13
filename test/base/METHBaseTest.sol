// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {WETH} from "solady/tokens/WETH.sol";
import {IMETH} from "src/interfaces/IMETH.sol";
import {MIN_INF_ALLOWANCE} from "src/METHConstants.sol";
import {Reverter} from "../mocks/Reverter.sol";
import {console2 as console} from "forge-std/console2.sol";

/// @author philogy <https://github.com/philogy>
abstract contract METHBaseTest is Test {
    IMETH meth;

    WETH immutable weth = new WETH();

    address immutable recovery = makeAddr("RECOVERY");

    function _setUp(address meth_) internal {
        meth = IMETH(meth_);
        vm.label(address(meth), "METH");
    }

    address internal immutable __methDealer = makeAddr("__methDealer");

    function testSymbol() public {
        bytes memory symbolCall = abi.encodeCall(meth.symbol, ());
        (bool success, bytes memory ret) = address(meth).staticcall(symbolCall);
        assertTrue(success);
        string memory symbol = abi.decode(ret, (string));
        assertEq(symbol, "METH");
    }

    function testName() public {
        bytes memory nameCall = abi.encodeCall(meth.name, ());
        (bool success, bytes memory ret) = address(meth).staticcall(nameCall);
        assertTrue(success);
        string memory name = abi.decode(ret, (string));
        assertEq(name, "Maximally Efficient Wrapped Ether");
    }

    function testDecimals() public {
        bytes memory decimalsCall = abi.encodeCall(meth.decimals, ());
        (bool success, bytes memory ret) = address(meth).staticcall(decimalsCall);
        assertTrue(success);
        uint8 decimals = abi.decode(ret, (uint8));
        assertEq(decimals, 18);
    }

    function test_fuzzingDeposit(address owner, uint128 amount) public {
        vm.deal(owner, amount);
        vm.prank(owner);
        meth.deposit{value: amount}();
        assertEq(meth.balanceOf(owner), amount);
    }

    function test_fuzzingDepositTo(address from, address to, uint128 amount) public {
        vm.deal(from, amount);
        vm.prank(from);
        meth.depositTo{value: amount}(to);
        assertEq(meth.balanceOf(to), amount);
    }

    function test_fuzzingDepositAndApprove(
        address owner,
        address spender,
        uint256 startBal,
        uint256 depositAmount,
        uint256 preAllowance,
        uint256 allowance
    ) public {
        vm.assume(owner != address(meth));
        depositAmount = bound(depositAmount, 0, type(uint256).max - startBal);

        dealMeth(owner, startBal);
        startHoax(owner, depositAmount);

        meth.approve(spender, preAllowance);
        assertEq(meth.allowance(owner, spender), preAllowance);

        meth.depositAndApprove{value: depositAmount}(spender, allowance);

        assertEq(meth.allowance(owner, spender), allowance);
        assertEq(meth.balanceOf(owner), startBal + depositAmount);
    }

    function test_fuzzingTransfer(address _from, address _to, uint128 _startAmount, uint128 _transferAmount) public {
        vm.assume(_startAmount >= _transferAmount);

        vm.deal(_from, _startAmount);
        vm.prank(_from);
        meth.deposit{value: _startAmount}();

        vm.prank(_from);
        meth.transfer(_to, _transferAmount);

        if (_from != _to) {
            assertEq(meth.balanceOf(_from), _startAmount - _transferAmount, "balance from after");
            assertEq(meth.balanceOf(_to), _transferAmount, "balance to after");
        } else {
            assertEq(meth.balanceOf(_from), _startAmount);
        }
    }

    function test_fuzzingApprove(address _owner, address _spender, uint256 _allowance1, uint256 _allowance2) public {
        assertEq(meth.allowance(_owner, _spender), 0);

        vm.prank(_owner);
        meth.approve(_spender, _allowance1);
        assertEq(meth.allowance(_owner, _spender), _allowance1);

        vm.prank(_owner);
        meth.approve(_spender, _allowance2);
        assertEq(meth.allowance(_owner, _spender), _allowance2);
    }

    function test_fuzzingTransferFromInfinite(
        address operator,
        address from,
        address to,
        uint256 allowance,
        uint128 startAmount,
        uint128 transferAmount
    ) public {
        allowance = bound(allowance, MIN_INF_ALLOWANCE, type(uint256).max);
        startAmount = uint128(bound(startAmount, 0, type(uint128).max));
        transferAmount = uint128(bound(transferAmount, 0, startAmount));

        // Setup.
        vm.deal(from, startAmount);
        vm.prank(from);
        meth.deposit{value: startAmount}();
        vm.prank(from);
        meth.approve(operator, allowance);

        // Actual test.
        vm.prank(operator);
        meth.transferFrom(from, to, transferAmount);

        assertEq(meth.allowance(from, operator), allowance);

        if (from == to) {
            assertEq(meth.balanceOf(from), startAmount);
        } else {
            assertEq(meth.balanceOf(from), startAmount - transferAmount);
            assertEq(meth.balanceOf(to), transferAmount);
        }
    }

    function test_fuzzingTransferFrom(
        address _operator,
        address _from,
        address _to,
        uint256 _allowance,
        uint128 _startAmount,
        uint128 _transferAmount
    ) public {
        _allowance = bound(_allowance, _startAmount, MIN_INF_ALLOWANCE - 1);
        vm.assume(_allowance >= _startAmount);
        vm.assume(_startAmount >= _transferAmount);

        // Setup.
        vm.deal(_from, _startAmount);
        vm.prank(_from);
        meth.deposit{value: _startAmount}();
        vm.prank(_from);
        meth.approve(_operator, _allowance);

        // Actual test.
        vm.prank(_operator);
        meth.transferFrom(_from, _to, _transferAmount);

        assertEq(meth.allowance(_from, _operator), _allowance - _transferAmount);
        if (_from != _to) {
            assertEq(meth.balanceOf(_from), _startAmount - _transferAmount);
            assertEq(meth.balanceOf(_to), _transferAmount);
        } else {
            assertEq(meth.balanceOf(_from), _startAmount);
        }
    }

    function testWithdraw() public {
        address owner = makeAddr("owner");

        uint256 startBal = 3.1 ether;
        dealMeth(owner, startBal);

        uint256 withdrawAmount = 2.6892 ether;
        vm.prank(owner);
        meth.withdraw(withdrawAmount);

        assertEq(meth.balanceOf(owner), startBal - withdrawAmount);
        assertEq(owner.balance, withdrawAmount);
    }

    function test_fuzzingWithdrawRevert(bytes memory revertData) public {
        Reverter reverter = new Reverter(revertData);

        startHoax(address(reverter), 1 wei);

        vm.expectRevert(revertData);
        meth.withdraw(0);

        vm.stopPrank();
    }

    function testWithdrawTo() public {
        address owner = makeAddr("owner");
        address recipient = makeAddr("recipient");

        uint256 startBal = 4.38 ether;
        dealMeth(owner, startBal);

        uint256 withdrawAmount = 0.7293 ether;
        vm.prank(owner);
        meth.withdrawTo(recipient, withdrawAmount);

        assertEq(meth.balanceOf(owner), startBal - withdrawAmount);
        assertEq(owner.balance, 0 ether);
        assertEq(recipient.balance, withdrawAmount);
    }

    function test_fuzzingDepositWithOld(address recipient1, address recipient2, uint128 amount1, uint128 amount2)
        public
    {
        amount2 = uint128(bound(amount2, 0, type(uint128).max - amount1));

        deal(address(weth), address(meth), amount1);
        meth.depositWithOldTo(recipient1);
        assertEq(meth.balanceOf(recipient1), amount1, "bal 1 wrong");
        assertEq(meth.reservesOld(), amount1);

        deal(address(weth), address(meth), amount1 + amount2);
        uint256 prevBal = meth.balanceOf(recipient2);
        meth.depositWithOldTo(recipient2);
        assertEq(meth.balanceOf(recipient2), prevBal + amount2, "bal 2 wrong");
        assertEq(meth.reservesOld(), amount1 + amount2);
    }

    function test_fuzzingWithdrawFromFiniteAllowance(
        address operator,
        address owner,
        uint256 startAmount,
        uint256 withdrawAmount,
        uint256 allowance
    ) public {
        assumePayable(operator);
        vm.assume(operator != address(meth));
        startAmount = bound(startAmount, 0, type(uint128).max);
        allowance = bound(allowance, 0, MIN_INF_ALLOWANCE - 1);
        withdrawAmount = bound(withdrawAmount, 0, min(allowance, startAmount));

        vm.prank(owner);
        meth.approve(operator, allowance);

        dealMeth(owner, startAmount);

        uint256 prevBal = operator.balance;

        vm.prank(operator);
        meth.withdrawFrom(owner, withdrawAmount);

        assertEq(operator.balance, prevBal + withdrawAmount);
        assertEq(meth.balanceOf(owner), startAmount - withdrawAmount);
        assertEq(meth.allowance(owner, operator), allowance - withdrawAmount);
    }

    function test_fuzzingWithdrawFromInfiniteAllowance(
        address operator,
        address owner,
        uint256 startAmount,
        uint256 withdrawAmount,
        uint256 allowance
    ) public {
        assumePayable(operator);
        vm.assume(operator != address(meth));

        startAmount = bound(startAmount, 0, type(uint128).max);
        allowance = bound(allowance, MIN_INF_ALLOWANCE, type(uint256).max);
        withdrawAmount = bound(withdrawAmount, 0, min(allowance, startAmount));

        vm.prank(owner);
        meth.approve(operator, allowance);
        dealMeth(owner, startAmount);
        assertEq(meth.balanceOf(owner), startAmount, "balance setup failed");

        uint256 prevBal = operator.balance;

        vm.prank(operator);
        meth.withdrawFrom(owner, withdrawAmount);

        assertEq(operator.balance, prevBal + withdrawAmount, "balance wrong");
        assertEq(meth.balanceOf(owner), startAmount - withdrawAmount, "withdraw wrong");
        assertEq(meth.allowance(owner, operator), allowance, "allowance wrong");
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
        meth.sweepLost();
        assertEq(meth.balanceOf(recovery), 2.8 ether);
    }

    function testNonPayableRevertsOnValue() public {
        // View methods
        _testNonPayable(meth.symbol.selector, "");
        _testNonPayable(meth.name.selector, "");
        _testNonPayable(meth.decimals.selector, "");
        _testNonPayable(meth.totalSupply.selector, "");
        _testNonPayable(meth.balanceOf.selector, abi.encode(vm.addr(1)));
        _testNonPayable(meth.allowance.selector, abi.encode(vm.addr(1), vm.addr(2)));

        // Non-view methods
        _testNonPayable(meth.withdraw.selector, abi.encode(uint256(0)));
        _testNonPayable(meth.withdrawTo.selector, abi.encode(vm.addr(3), uint256(0)));
        _testNonPayable(meth.withdrawAll.selector, "");
        _testNonPayable(meth.withdrawAllTo.selector, abi.encode(vm.addr(1)));
        _testNonPayable(meth.transfer.selector, abi.encode(vm.addr(1), uint256(0)));
    }

    function _testNonPayable(bytes4 _selector, bytes memory _addedData) internal {
        bytes memory dataForCall = abi.encodePacked(_selector, _addedData);
        (bool success, bytes memory revertData) = address(meth).call{value: 1 wei}(dataForCall);
        assertFalse(success, "Non-payable function accepted value");
        assertEq(revertData, "", "msg.value revert should be empty");
    }

    function test_fuzzingDefaultBalance(address account) public {
        assertEq(meth.balanceOf(account), 0);
    }

    function test_fuzzingDefaultAllowance(address owner, address spender) public {
        assertEq(meth.allowance(owner, spender), 0);
    }

    function dealMeth(address to, uint256 amount) internal {
        uint256 balBefore = __methDealer.balance;
        hoax(__methDealer, amount);
        meth.depositTo{value: amount}(to);
        vm.deal(__methDealer, balBefore);
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }

    function max(uint256 x, uint256 y) internal pure returns (uint256) {
        return x > y ? x : y;
    }
}
