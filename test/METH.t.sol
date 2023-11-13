// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {METHBaseTest} from "./base/METHBaseTest.sol";
import {HuffDeployer} from "./utils/HuffDeployer.sol";
import {LibString} from "solady/utils/LibString.sol";

/// @author philogy <https://github.com/philogy>
contract METHTest is METHBaseTest {
    using LibString for address;

    function setUp() public {
        string[] memory args = new string[](2);
        args[0] = string(abi.encodePacked("LOST_N_FOUND=", recovery.toHexString()));
        args[1] = string(abi.encodePacked("OLD_WETH=", address(weth).toHexString()));
        address meth_ = HuffDeployer.deploy("src/meth-huff/METH.huff", args, 0);
        _setUp(meth_);
    }
}
