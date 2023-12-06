// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {MIN_INF_ALLOWANCE} from "src/METHConstants.sol";
import {Reverter} from "../mocks/Reverter.sol";
import {console2 as console} from "forge-std/console2.sol";
import {METHBase} from "./METHBase.sol";

/// @author philogy <https://github.com/philogy>
abstract contract METHBaseTest is METHBase {
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

    function test_transfer() public {
        address from = makeAddr("from");
        uint256 fromStartBal = 10.2e18;
        address to = makeAddr("to");
        uint256 toStartBal = 0.031e18;

        dealMeth(from, fromStartBal);
        dealMeth(to, toStartBal);

        uint256 transferAmount = 0.57e18;
        vm.prank(from);
        meth.transfer(to, transferAmount);

        assertEq(meth.balanceOf(from), fromStartBal - transferAmount);
        assertEq(meth.balanceOf(to), toStartBal + transferAmount);
    }

    function test_fuzzingTransferSame(address from, uint256 startBal, uint256 amount) public {
        dealMeth(from, startBal);

        if (amount > startBal) {
            vm.prank(from);
            vm.expectRevert();
            meth.transfer(from, amount);
        } else {
            vm.prank(from);
            meth.transfer(from, amount);
            assertEq(meth.balanceOf(from), startBal);
        }
    }

    function test_fuzzingTransferNotSame(
        address from,
        address to,
        // Amounts u128 to emulate practical ETH supply (METH allows overflows)
        uint128 fromStartAmount,
        uint128 toStartAmount,
        uint256 transferAmount
    ) public {
        // Same transfer tested above
        vm.assume(from != to);

        transferAmount = bound(transferAmount, 0, fromStartAmount);
        dealMeth(from, fromStartAmount);
        dealMeth(to, toStartAmount);

        vm.prank(from);
        meth.transfer(to, transferAmount);

        assertEq(meth.balanceOf(from), uint256(fromStartAmount) - transferAmount, "balance from after");
        assertEq(meth.balanceOf(to), uint256(toStartAmount) + transferAmount, "balance to after");
    }

    function test_fuzzingApprove(address owner, address spender, uint256 allowance1, uint256 allowance2) public {
        assertEq(meth.allowance(owner, spender), 0);

        vm.prank(owner);
        meth.approve(spender, allowance1);
        assertEq(meth.allowance(owner, spender), allowance1);

        vm.prank(owner);
        meth.approve(spender, allowance2);
        assertEq(meth.allowance(owner, spender), allowance2);
    }

    function test_transferFrom() public {
        address owner = makeAddr("owner");
        uint256 ownerStartBal = 10.2e18;
        address spender = makeAddr("spender");
        uint256 spenderStartAllowance = 3.7e18;
        address to = makeAddr("to");
        uint256 toStartBal = 0.031e18;
        uint256 transferAmount = 1.6819e18;

        dealMeth(owner, ownerStartBal);
        dealMeth(to, toStartBal);

        vm.prank(owner);
        meth.approve(spender, spenderStartAllowance);

        vm.prank(spender);
        meth.transferFrom(owner, to, transferAmount);

        assertEq(meth.balanceOf(owner), ownerStartBal - transferAmount);
        assertEq(meth.balanceOf(to), toStartBal + transferAmount);
        assertEq(meth.allowance(owner, spender), spenderStartAllowance - transferAmount);
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
        address operator,
        address from,
        address to,
        uint256 allowance,
        uint128 startAmount,
        uint128 transferAmount
    ) public {
        allowance = bound(allowance, startAmount, MIN_INF_ALLOWANCE - 1);
        vm.assume(allowance >= startAmount);
        vm.assume(startAmount >= transferAmount);

        // Setup.
        vm.deal(from, startAmount);
        vm.prank(from);
        meth.deposit{value: startAmount}();
        vm.prank(from);
        meth.approve(operator, allowance);

        // Actual test.
        vm.prank(operator);
        meth.transferFrom(from, to, transferAmount);

        assertEq(meth.allowance(from, operator), allowance - transferAmount);
        if (from != to) {
            assertEq(meth.balanceOf(from), startAmount - transferAmount);
            assertEq(meth.balanceOf(to), transferAmount);
        } else {
            assertEq(meth.balanceOf(from), startAmount);
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

    function test_fuzzingNoncesStartAtZero(address owner) public {
        assertEq(meth.nonces(owner), 0);
    }

    function test_fuzzingPermit(
        address submitter,
        uint256 startAllowance,
        uint256 newAllowance,
        uint256 nonce,
        uint256 currentTime,
        uint256 deadline
    ) public {
        vm.warp(bound(currentTime, 0, deadline));

        Account memory owner = makeAccount("owner");
        nonce = bound(nonce, 0, type(uint256).max - 1);
        _setNonce(owner.addr, nonce);
        assertEq(meth.nonces(owner.addr), nonce);

        address spender = makeAddr("spender");

        vm.prank(owner.addr);
        meth.approve(spender, startAllowance);
        assertEq(meth.allowance(owner.addr, spender), startAllowance);

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(owner, spender, newAllowance, nonce, deadline);

        vm.prank(submitter);
        meth.permit(owner.addr, spender, newAllowance, deadline, v, r, s);
        assertEq(meth.allowance(owner.addr, spender), newAllowance);
        assertEq(meth.nonces(owner.addr), nonce + 1);
    }

    function test_debug() public {
        meth.DOMAIN_SEPARATOR();
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

    function test_fuzzingDefaultBalance(address account) public {
        assertEq(meth.balanceOf(account), 0);
    }

    function test_fuzzingDefaultAllowance(address owner, address spender) public {
        assertEq(meth.allowance(owner, spender), 0);
    }
}
