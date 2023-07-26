// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {METHMetadataLib} from "./METHMetadataLib.sol";

/// @author philogy <https://github.com/philogy>
contract MetadataDeployer {
    constructor(uint8 decimals, string memory symbol, string memory name) {
        bytes memory metadataContainer = METHMetadataLib.encodeMetadataContainer(decimals, symbol, name);
        assembly {
            return(add(metadataContainer, 0x20), mload(metadataContainer))
        }
    }
}
