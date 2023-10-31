// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {IMETH} from "src/interfaces/IMETH.sol";
import {HuffDeployer} from "../utils/HuffDeployer.sol";
import {LibString} from "solady/utils/LibString.sol";
import {WETH} from "solady/tokens/WETH.sol";

/// @author philogy <https://github.com/philogy>
abstract contract METHBaseTest is Test {
    using LibString for address;

    IMETH meth;

    WETH immutable weth = new WETH();

    address immutable recovery = makeAddr("RECOVERY");

    function setUp() public virtual {
        string[] memory args = new string[](2);
        args[0] = string(abi.encodePacked("LOST_N_FOUND=", recovery.toHexString()));
        args[1] = string(abi.encodePacked("OLD_WETH=", address(weth).toHexString()));

        meth = IMETH(HuffDeployer.deploy("src/meth-huff/METH.huff", args, 0));

        assertGt(address(meth).code.length, 0, "Failed to deploy meth");

        vm.label(address(meth), "METH");
    }
}
