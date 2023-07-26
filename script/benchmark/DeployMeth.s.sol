// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {MetadataDeployer} from "src/utils/MetadataDeployer.sol";

/// @author philogy <https://github.com/philogy>
contract DeployMethScript is Script, Test {
    address internal constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function run() public returns (address meth) {
        string[] memory args = new string[](3);
        args[0] = "huffc";
        args[1] = "-b";
        args[2] = "./src/METH_WETH.huff";
        bytes memory methCode = vm.ffi(args);

        uint256 sk = vm.envUint("PRIV_KEY");

        vm.startBroadcast(sk);

        new MetadataDeployer(18, "METH", "Minified Wrapped Ether");

        assembly {
            meth := create(0, add(methCode, 0x20), mload(methCode))
        }

        vm.stopBroadcast();
    }
}
