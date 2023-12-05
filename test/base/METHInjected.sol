// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {METHBase} from "./METHBase.sol";
import {HuffDeployer, CodeType} from "../utils/HuffDeployer.sol";
import {LibString} from "solady/utils/LibString.sol";

/// @author philogy <https://github.com/philogy>
abstract contract METHInjected is METHBase {
    using LibString for address;

    constructor() {
        string[] memory args = new string[](2);
        args[0] = string(abi.encodePacked("LOST_N_FOUND=", recovery.toHexString()));
        args[1] = string(abi.encodePacked("OLD_WETH=", address(weth).toHexString()));
        bytes memory methCode = HuffDeployer.getBytecode(CodeType.Runtime, "src/meth-huff/METH.huff", args);

        vm.etch(address(meth), methCode);
    }
}
