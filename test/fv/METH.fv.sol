// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {METH} from "src/METH.sol";

/// @author philogy <https://github.com/philogy>
contract METHSymbolicTest is Test {
    function proveTransfer(address from, address to, address other, uint256 amount) public {
        METH meth = new METH();

        uint256 fromBalBefore = meth.balanceOf(from);
        uint256 toBalBefore = meth.balanceOf(to);
        uint256 otherBalBefore = meth.balanceOf(other);

        /**
         * @dev Assumption: Can never reach a state where bal(from) + bal(to) could overflow a uint256 (if from != to).
         * - Assuming the total supply of ETH does not exceed 2^256 - 1 (currently ~2^90)
         * - *AND* The solvency invariant (sum(balances) == total_eth_deposited) has been upheld till now
         * => The sum of the balance of two different accounts A & B cannot overflow:
         *          2**256 > total_eth_suply >= total_eth_deposited == sum(balances) >= bal(A) + bal(B)
         */
        if (from != to) {
            require(noOverflow(fromBalBefore, toBalBefore));
        }

        vm.prank(from);
        meth.transfer(to, amount);

        // Invariant: For transfer not to revert must have had sufficient balance.
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
            // Invariant (implicit, sanity check): Recipient's balance cannot be overflowing
            assert(noOverflow(toBalBefore, amount));
        }

        // Invariant: Transfers between A and B should not affect the balance of accounts C ∉ {A, B}
        require(other != from && other != to);
        assert(meth.balanceOf(other) == otherBalBefore);
    }

    function noOverflow(uint256 x, uint256 y) internal pure returns (bool) {
        return type(uint256).max - x >= y;
    }
}
