// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {YAM_WETH} from "../src/YetAnotherMaximizedWETH.sol";

contract YAM_WETH_Test is Test {
    YAM_WETH weth;

    address mainUser = vm.addr(1);

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event PrimaryOperatorSet(address indexed operator);

    function setUp() public {
        weth = new YAM_WETH();
    }

    function testName() public {
        assertEq(weth.name(), "Yet Another Maximized Wrapped Ether Contract");
    }

    function testSymbol() public {
        assertEq(weth.symbol(), "WETH");
    }

    function testDefaultBalance(address _account) public {
        vm.assume(_account != address(0));
        assertEq(weth.balanceOf(_account), 0);
    }

    function testDeposit(address _account, uint96 _amount) public {
        vm.assume(_account != address(0));
        vm.deal(_account, _amount);
        vm.prank(_account);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), _account, _amount);
        assertTrue(weth.deposit{value: _amount}());
        assertEq(weth.balanceOf(_account), _amount);
    }

}
