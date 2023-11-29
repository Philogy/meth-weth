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

    /// @dev Minimal methods implemented to silence warnings as they'll be replaced in the
    /// constructor.

    // forgefmt: disable-start
    function decimals() external pure returns (uint8) { assert(false); return 0; }
    function name() external pure returns (string memory) { assert(false); return ""; }
    function symbol() external pure returns (string memory) { assert(false); return ""; }
    function totalSupply() external pure returns (uint256) { assert(false); return 0; }
    function balanceOf(address) external pure returns (uint256) { assert(false); return 0; }
    function allowance(address, address) external pure returns (uint256) { assert(false); return 0; }
    function transfer(address, uint256) external pure { assert(false); }
    function transferFrom(address, address, uint256) external pure { assert(false); }
    function approve(address, uint256) external pure { assert(false); }
    function deposit() external payable { assert(false); }
    function depositTo(address) external payable { assert(false); }
    function depositAndApprove(address, uint256) external payable { assert(false); }
    function withdraw(uint256) external pure { assert(false); }
    function withdrawTo(address, uint256) external pure { assert(false); }
    function withdrawAll() external pure { assert(false); }
    function withdrawAllTo(address) external pure { assert(false); }
    function withdrawFrom(address, uint256) external pure { assert(false); }
    function withdrawFromTo(address, address, uint256) external pure { assert(false); }
    function sweepLost() external pure { assert(false); }
    function depositWithOldTo(address) external pure { assert(false); }
    function withdrawAsOldTo(address, uint256) external pure { assert(false); }
    function reservesOld() external pure returns (uint256) { assert(false); return 0; }
    // forgefmt: disable-end
}
