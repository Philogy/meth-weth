// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {IMETH} from "src/interfaces/IMETH.sol";
import {METHCode} from "./METHCode.sol";

/// @author philogy <https://github.com/philogy>
contract METHSymbolicTest is Test, METHCode {
    function proveTransfer(address from, address to, address other, uint256 amount) public {
        IMETH meth = _deployMETH();

        vm.store(
            address(meth),
            bytes32(uint256(0xacab)),
            bytes32(0x800000000000000000003ffffffffffff8000000000007e00100000000000083)
        );
        vm.store(
            address(meth),
            bytes32(uint256(0x00a0008000000003000001db3bf7e6000000000000)),
            bytes32(0x7c00000000000000000000000000000003fffffffffffdafffbfffffffffffff)
        );

        // Assumption: `other` is not one of the two addresses.
        require(other != from && other != to);
        uint256 otherBalBefore = meth.balanceOf(other);

        uint256 fromBalBefore = meth.balanceOf(from);
        uint256 toBalBefore = meth.balanceOf(to);

        // Assumption: If not self-sending, bal(from) + bal(to) do not overflow 1 EVM word (2**256 - 1)
        if (from != to) {
            require(fromBalBefore <= type(uint256).max - toBalBefore);
        }

        vm.prank(from);
        meth.transfer(to, amount);

        // Invariant: For transfer not to revert must have sufficient balance.
        assert(fromBalBefore >= amount);

        if (from == to) {
            // Invariant: For self-transfers balance must remain unchanged.
            assert(fromBalBefore == meth.balanceOf(from));
        } else {
            // Invariant: For normal-transfers balances must've been changed correctly
            assert(fromBalBefore - amount == meth.balanceOf(from));
            unchecked {
                assert(toBalBefore + amount == meth.balanceOf(to));
            }
            // Invariant (implicit sanity check): Recipients balance cannot be overflowing
            assert(type(uint256).max - toBalBefore >= amount);
        }

        // Invariant: Transfer between account `x` and `y` should not affect balance of account `z`.
        assert(meth.balanceOf(other) == otherBalBefore);
    }

    function noOverflow(uint256 x, uint256 y) internal pure returns (bool) {
        return type(uint256).max - x >= y;
    }
}
/*
0x
6b5c6370
000000000000000000000000 0xa0008000000003000001db3bf7e6000000000000
000000000000000000000000 0xa0008000000003000001db3bf7e6000000000000
000000000000000000000000 0x5fff3ffffffffcfffffe24c40819ffffffffffff
07fffffffffffffffffffffffffffffff8000000000004a00080000000000001


    */
