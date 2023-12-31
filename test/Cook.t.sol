// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Cook, CrystallizationTray} from "../src/deployment/Cook.sol";
import {MockLab} from "./mocks/MockLab.sol";

/// @author philogy <https://github.com/philogy>
contract CookTest is Test {
    address immutable owner = makeAddr("owner");

    bytes32 salt = bytes32(hex"01");
    address predicted;

    Cook cook;

    function setUp() public {
        vm.prank(owner);
        cook = new Cook();
        assertEq(cook.owner(), owner);

        predicted = computeCreate2Address(salt, keccak256(type(CrystallizationTray).creationCode), address(cook));
    }

    function test_onlyOwnerCanCook() public {
        MockLab lab = new MockLab(hex"00");

        vm.prank(makeAddr("notOwner"));
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        cook.cookWithLab(address(lab), bytes32(0));
    }

    function test_deployStop() public {
        MockLab lab = new MockLab(hex"00");

        vm.prank(owner);
        address meth = cook.cookWithLab(address(lab), salt);

        assertEq(meth, predicted);
        assertEq(meth.code, lab.data());
    }

    function test_deployReturn69() public {
        MockLab lab = new MockLab(hex"60455952593df3");

        vm.prank(owner);
        address meth = cook.cookWithLab(address(lab), salt);

        assertEq(meth, predicted);
        assertEq(meth.code, lab.data());
    }
}
