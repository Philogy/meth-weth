// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IMETH} from "./interfaces/IMETH.sol";
import {METH_RUNTIME} from "./METHConstants.sol";

/// @author philogy <https://github.com/philogy>
contract METH is IMETH {
    constructor() {
        bytes memory code = METH_RUNTIME;

        // Bypasses deployment of Solidity generated runtime.
        /// @solidity memory-safe-assembly
        assembly {
            let codeStart := add(code, 0x20)
            return(codeStart, mload(code))
        }
    }

    ////////////////////////////////////////////////////////////////
    //                         INTERFACE                          //
    ////////////////////////////////////////////////////////////////

    /// @dev Minimal methods implemented to silence warnings. Actual implemenations given by the
    //constructor.

    // forgefmt: disable-start
    bool _state;
    function decimals          ()                          external view returns (uint8)         { assert(_state); return 0 ; }
    function name              ()                          external view returns (string memory) { assert(_state); return ""; }
    function symbol            ()                          external view returns (string memory) { assert(_state); return ""; }
    function totalSupply       ()                          external view returns (uint256)       { assert(_state); return 0 ; }
    function balanceOf         (address)                   external view returns (uint256)       { assert(_state); return 0 ; }
    function allowance         (address, address)          external view returns (uint256)       { assert(_state); return 0 ; }
    function reservesOld       ()                          external view returns (uint256)       { assert(_state); return 0 ; }
    function transfer          (address, uint256)          external                              { assert(_state = false);    }
    function transferFrom      (address, address, uint256) external                              { assert(_state = false);    }
    function approve           (address, uint256)          external                              { assert(_state = false);    }
    function deposit           ()                          external payable                      { assert(_state = false);    }
    function depositTo         (address)                   external payable                      { assert(_state = false);    }
    function depositAndApprove (address, uint256)          external payable                      { assert(_state = false);    }
    function withdraw          (uint256)                   external                              { assert(_state = false);    }
    function withdrawTo        (address, uint256)          external                              { assert(_state = false);    }
    function withdrawAll       ()                          external                              { assert(_state = false);    }
    function withdrawAllTo     (address)                   external                              { assert(_state = false);    }
    function withdrawFrom      (address, uint256)          external                              { assert(_state = false);    }
    function withdrawFromTo    (address, address, uint256) external                              { assert(_state = false);    }
    function sweepLost         ()                          external                              { assert(_state = false);    }
    function depositWithOldTo  (address)                   external                              { assert(_state = false);    }
    function withdrawAsOldTo   (address, uint256)          external                              { assert(_state = false);    }
    // forgefmt: disable-end
}
