// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {IMETH} from "src/interfaces/IMETH.sol";
import {HuffDeployer} from "smol-huff-deployer/HuffDeployer.sol";
import {LibString} from "solady/utils/LibString.sol";

/// @author philogy <https://github.com/philogy>
abstract contract METHBaseTest is Test {
    using LibString for address;

    IMETH meth;

    address recovery = makeAddr("RECOVERY");

    uint256 internal constant MAINNET_CHAIN_ID = 0x1;

    function setUp() public {
        vm.chainId(MAINNET_CHAIN_ID);
        string[] memory args = new string[](1);
        args[0] = string(abi.encodePacked("RECOVERY_ADDR=", recovery.toHexString()));
        meth = IMETH((new HuffDeployer()).deploy("src/METH_WETH.huff", args, 0));
    }
}
