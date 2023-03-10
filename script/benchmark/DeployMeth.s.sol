// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {HuffDeployer} from "../../test/utils/HuffDeployer.sol";

/// @author philogy <https://github.com/philogy>
contract DeployMethScript is Script, Test {
    address internal constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function run() public {
        HuffDeployer huffDeployer = new HuffDeployer();

        bytes memory methCode = huffDeployer.getBytecode("./src/METH_WETH.huff", new string[](0));

        vm.startBroadcast(vm.envUint("PRIV_KEY"));
        address meth;
        assembly {
            meth := create(0, add(methCode, 0x20), mload(methCode))
        }

        emit log_named_address("meth", meth);

        vm.stopBroadcast();
    }
}
