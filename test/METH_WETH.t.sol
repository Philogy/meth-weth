// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {METHBaseTest} from "./utils/METHBaseTest.sol";
import {HuffDeployer} from "smol-huff-deployer/HuffDeployer.sol";
import {MIN_INF_ALLOWANCE} from "src/METHConstants.sol";
import {console2 as console} from "forge-std/console2.sol";

interface ShanghaiChecker {
    function shanghaiEnabled() external view returns (bool);
    function usePush0() external view;
}

/// @author philogy <https://github.com/philogy>
contract METH_WETHTest is Test, METHBaseTest {
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Deposit(address indexed to, uint256 amount);
    event Withdrawal(address indexed from, uint256 amount);

    address giver = makeAddr("__setup_giver");

    modifier realAddr(address _a) {
        vm.assume(_a != address(0));
        _;
    }

    modifier acceptsETH(address recipient) {
        address sender = makeAddr("tempSender");
        uint256 prevBal = recipient.balance;
        hoax(sender, 1 wei);
        (bool success,) = recipient.call{value: 1 wei}("");
        vm.assume(success);
        vm.deal(recipient, prevBal);
        vm.deal(sender, 0);
        _;
    }

    function testSymbol() public {
        bytes memory symbolCall = abi.encodeCall(meth.symbol, ());
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
        bytes memory nameCall = abi.encodeCall(meth.name, ());
        (bool success, bytes memory ret) = address(meth).staticcall(nameCall);
        assertTrue(success);
        assertEq(ret.length, 0x80);
        assertEq(_loadWord(ret, 0x20), 0x20);
        assertEq(_loadWord(ret, 0x40), 33);
        assertEq(_loadWord(ret, 0x60), uint256(bytes32("Maximally Efficient Wrapped Ethe")));
        assertEq(_loadWord(ret, 0x80), uint256(bytes32("r")));
        string memory name = abi.decode(ret, (string));
        assertEq(name, "Maximally Efficient Wrapped Ether");
    }

    function testDecimals() public {
        bytes memory decimalsCall = abi.encodeCall(meth.decimals, ());
        (bool success, bytes memory ret) = address(meth).staticcall(decimalsCall);
        assertTrue(success);
        assertEq(ret.length, 0x20);
        assertEq(_loadWord(ret, 0x20), 18);
        uint8 decimals = abi.decode(ret, (uint8));
        assertEq(decimals, 18);
    }

    function test_fuzzingDeposit(address owner, uint128 amount) public {
        vm.deal(owner, amount);
        vm.prank(owner);
        expectDepositEvent(owner, amount);
        meth.deposit{value: amount}();
        assertEq(meth.balanceOf(owner), amount);
    }

    function test_fuzzingDepositTo(address from, address to, uint128 amount) public {
        vm.deal(from, amount);
        vm.prank(from);
        expectDepositEvent(to, amount);
        meth.depositTo{value: amount}(to);
        assertEq(meth.balanceOf(to), amount);
    }

    function test_fuzzingTransfer(address _from, address _to, uint128 _startAmount, uint128 _transferAmount) public {
        vm.assume(_startAmount >= _transferAmount);

        vm.deal(_from, _startAmount);
        vm.prank(_from);
        meth.deposit{value: _startAmount}();

        vm.prank(_from);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_from, _to, _transferAmount);
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
        vm.expectEmit(true, true, true, true);
        emit Transfer(from, to, transferAmount);
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
        vm.expectEmit(true, true, true, true);
        emit Transfer(_from, _to, _transferAmount);
        meth.transferFrom(_from, _to, _transferAmount);

        assertEq(meth.allowance(_from, _operator), _allowance - _transferAmount);
        if (_from != _to) {
            assertEq(meth.balanceOf(_from), _startAmount - _transferAmount);
            assertEq(meth.balanceOf(_to), _transferAmount);
        } else {
            assertEq(meth.balanceOf(_from), _startAmount);
        }
    }

    function test_fuzzingWithdrawFromFiniteAllowance(
        address operator,
        address owner,
        uint256 startAmount,
        uint256 withdrawAmount,
        uint256 allowance
    ) public acceptsETH(operator) {
        vm.assume(operator != address(meth));
        startAmount = bound(startAmount, 0, type(uint128).max);
        allowance = bound(allowance, 0, MIN_INF_ALLOWANCE - 1);
        withdrawAmount = bound(withdrawAmount, 0, min(allowance, startAmount));

        vm.prank(owner);
        meth.approve(operator, allowance);
        _grantMeth(owner, startAmount);

        uint256 prevBal = operator.balance;

        vm.prank(operator);
        expectWithdrawalEvent(owner, withdrawAmount);
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
    ) public acceptsETH(operator) {
        vm.assume(operator != address(meth));

        startAmount = bound(startAmount, 0, type(uint128).max);
        allowance = bound(allowance, MIN_INF_ALLOWANCE, type(uint256).max);
        withdrawAmount = bound(withdrawAmount, 0, min(allowance, startAmount));

        vm.prank(owner);
        meth.approve(operator, allowance);
        _grantMeth(owner, startAmount);
        assertEq(meth.balanceOf(owner), startAmount, "balance setup failed");

        uint256 prevBal = operator.balance;

        vm.prank(operator);
        expectWithdrawalEvent(owner, withdrawAmount);
        meth.withdrawFrom(owner, withdrawAmount);

        assertEq(operator.balance, prevBal + withdrawAmount, "balance wrong");
        assertEq(meth.balanceOf(owner), startAmount - withdrawAmount, "withdraw wrong");
        assertEq(meth.allowance(owner, operator), allowance, "allowance wrong");
    }

    function testUnimplementedReverts() public {
        uint32[] memory exceptionalSelectors = new uint32[](10);
        exceptionalSelectors[0] = 0x0a000000;
        exceptionalSelectors[1] = 0x21000000;
        exceptionalSelectors[2] = 0x24000000;
        exceptionalSelectors[3] = 0x29000000;
        exceptionalSelectors[4] = 0x2f000000;
        exceptionalSelectors[5] = 0x4b000000;
        exceptionalSelectors[6] = 0x86000000;
        exceptionalSelectors[7] = 0xaa000000;
        exceptionalSelectors[8] = 0xae000000;
        exceptionalSelectors[9] = 0xcb000000;

        for (uint256 i = 0; i < exceptionalSelectors.length; i++) {
            uint32 selector = exceptionalSelectors[i];
            uint256 jumpDest = (selector >> 0x12) | 0x3f;

            assertTrue(address(meth).code[jumpDest] != 0x5b, "MISSING JUMPDEST");
        }

        address meth_ = address(meth);
        uint256 maxGas = 100_000;

        for (uint256 i = 0; i < 256; i++) {
            uint32 selector = uint32(i << 24);
            bool isExceptional = false;
            for (uint256 j = 0; j < exceptionalSelectors.length; j++) {
                if (selector == exceptionalSelectors[j]) {
                    isExceptional = true;
                    break;
                }
            }

            uint256 gasChange;
            bool success;
            assembly {
                mstore(0x00, selector)
                let gasBefore := gas()
                success := call(maxGas, meth_, 0, 0x1c, 0x04, 0x00, 0x00)
                gasChange := sub(gasBefore, gas())
            }

            if (isExceptional) {
                assertGt(gasChange, maxGas, "Exceptional Didn't Use Enough");
            } else {
                // Some methods will cheaply revert immediately, others like `transferFrom` will
                // only revert once the first bundled check is reached.
                if (gasChange >= 5000) {
                    console.log("selector %x too much", selector);
                    fail();
                }
            }

            assertFalse(success, "Unimplemented selector should've reverted");
        }
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

    function _loadWord(bytes memory _bytes, uint256 _offset) internal pure returns (uint256 word) {
        assembly {
            word := mload(add(_bytes, _offset))
        }
    }

    function _grantMeth(address recipient, uint256 amount) internal {
        hoax(giver, amount);
        meth.depositTo{value: amount}(recipient);
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }

    function max(uint256 x, uint256 y) internal pure returns (uint256) {
        return x > y ? x : y;
    }

    function expectDepositEvent(address owner, uint256 amount) internal {
        assertLt(amount, 1 << 128);
        bytes32 depositEventSig = keccak256("Deposit(address,uint256)");
        vm.expectEmit(true, true, true, true);
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, amount)
            log2(0x10, 0x10, depositEventSig, owner)
        }
    }

    function expectWithdrawalEvent(address owner, uint256 amount) internal {
        assertLt(amount, 1 << 128);
        bytes32 withdrawalEventSig = keccak256("Withdrawal(address,uint256)");
        vm.expectEmit(true, true, true, true);
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, amount)
            log2(0x10, 0x10, withdrawalEventSig, owner)
        }
    }
}
