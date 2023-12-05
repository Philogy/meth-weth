// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {WETH} from "solady/tokens/WETH.sol";
import {METH} from "../mocks/MockMETH.sol";

/// @author philogy <https://github.com/philogy>
contract METHBase is Test {
    WETH immutable weth = new WETH();
    address immutable recovery = makeAddr("RECOVERY");
    address internal immutable __methDealer = makeAddr("__methDealer");
    METH immutable meth = new METH();

    constructor() {
        vm.label(address(meth), "METH");
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
