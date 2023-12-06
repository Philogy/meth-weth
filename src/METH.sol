// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IMETH} from "./interfaces/IMETH.sol";
import {METH_RUNTIME} from "./METHConstants.sol";
import {MockMETH} from "../test/mocks/MockMETH.sol";

/// @author philogy <https://github.com/philogy>
contract METH is IMETH, MockMETH {
    constructor() {
        bytes memory code = METH_RUNTIME;

        // Bypasses deployment of Solidity generated runtime.
        /// @solidity memory-safe-assembly
        assembly {
            let codeStart := add(code, 0x20)
            return(codeStart, mload(code))
        }
    }
}
