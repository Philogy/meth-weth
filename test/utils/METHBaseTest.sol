// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {IMETH} from "src/interfaces/IMETH.sol";
import {HuffDeployer} from "smol-huff-deployer/HuffDeployer.sol";
import {LibString} from "solady/utils/LibString.sol";
import {METHMetadataLib} from "src/utils/METHMetadataLib.sol";
import {WETH} from "solady/tokens/WETH.sol";

/// @author philogy <https://github.com/philogy>
abstract contract METHBaseTest is Test {
    using LibString for address;

    IMETH meth;

    WETH weth;

    address recovery = makeAddr("RECOVERY");

    address internal immutable TEST_METADATA = address(uint160(uint256(keccak256("METH.metadata-source.test"))));

    function setUp() public virtual {
        weth = new WETH();
        string[] memory args = new string[](2);
        args[0] = string(abi.encodePacked("LOST_N_FOUND=", recovery.toHexString()));
        args[1] = string(abi.encodePacked("OLD_WETH=", address(weth).toHexString()));

        vm.etch(TEST_METADATA, METHMetadataLib.encodeMetadataContainer(18, "METH", "Maximally Efficient Wrapped Ether"));

        meth = IMETH((new HuffDeployer()).deploy("src/METH_WETH.huff", args, 0));

        vm.label(address(meth), "METH");
    }
}
