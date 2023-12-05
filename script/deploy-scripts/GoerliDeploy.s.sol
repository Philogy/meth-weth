// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {WETH} from "solady/tokens/WETH.sol";
import {LibString} from "solady/utils/LibString.sol";
import {HuffDeployer} from "test/utils/HuffDeployer.sol";

/// @author philogy <https://github.com/philogy>
contract GoerliDeploy is Script, Test {
    function run() public {
        uint256 privateKey = vm.envUint("PRIV_KEY");
        vm.startBroadcast(privateKey);

        WETH weth = new WETH();

        string[] memory consts = new string[](1);
        consts[0] = string.concat("OLD_WETH=", LibString.toHexString(address(weth)));

        HuffDeployer.deploy("src/meth-huff/METH.huff", consts, 0);

        vm.stopBroadcast();
    }
}
