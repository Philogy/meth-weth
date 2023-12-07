// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {METHInjected} from "../base/METHInjected.sol";

/// @author philogy <https://github.com/philogy>
/// @dev This "test" only runs the functions for the purposes of generating a gas report, no
/// functionality is actuallly tested.
contract METHGasTest is METHInjected {
    function test_transfer() public {
        address from = makeAddr("from");
        address to = makeAddr("to");

        deal(address(meth), from, 3e18);
        deal(address(meth), to, 2.1e18);

        vm.prank(from);
        meth.transfer(to, 1e18);
    }

    function test_transferFromInfinite() public {
        address owner = makeAddr("owner");
        address spender = makeAddr("spender");
        address to = makeAddr("to");

        deal(address(meth), owner, 69e18);
        deal(address(meth), to, 420e18);

        vm.prank(owner);
        meth.approve(spender, type(uint256).max);

        vm.prank(spender);
        meth.transferFrom(owner, to, 21e18);
    }

    function test_transferFromFinite() public {
        address owner = makeAddr("owner");
        address spender = makeAddr("spender");
        address to = makeAddr("to");

        deal(address(meth), owner, 69e18);
        deal(address(meth), to, 420e18);

        vm.prank(owner);
        meth.approve(spender, 34e18);

        vm.prank(spender);
        meth.transferFrom(owner, to, 21e18);
    }

    function test_balanceOf() public {
        address user = makeAddr("user");
        deal(address(meth), user, 1 wei);
        meth.balanceOf(user);
    }

    function test_nonces() public {
        address user = makeAddr("user");
        _setNonce(user, 1);
        meth.nonces(user);
    }

    function test_allowance() public {
        address from = makeAddr("from");
        address to = makeAddr("to");
        vm.prank(from);
        meth.approve(to, 34.32 ether);

        meth.allowance(from, to);
    }

    function test_approve() public {
        address from = makeAddr("from");
        address to = makeAddr("to");
        vm.prank(from);
        meth.approve(to, 34.32 ether);
        vm.prank(from);
        meth.approve(to, 3.2 ether);
    }

    function test_name() public view {
        meth.name();
    }

    function test_symbol() public view {
        meth.symbol();
    }

    function test_decimals() public view {
        meth.decimals();
    }
}
