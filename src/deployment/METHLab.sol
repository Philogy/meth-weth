// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ILab} from "../interfaces/ILab.sol";
import {METH_RUNTIME} from "../METHConstants.sol";
import {LibString} from "solady/utils/LibString.sol";

/// @author philogy <https://github.com/philogy>
contract METHLab is ILab {
    using LibString for string;

    string internal constant VERSION = "1.0";

    error InvalidSymbol();

    address public immutable OLD_WETH;

    constructor(address oldWeth) {
        OLD_WETH = oldWeth;
    }

    function getFinalProduct() external view {
        bytes memory code = METH_RUNTIME;

        address oldWeth = OLD_WETH;
        string memory name = "";

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(VERSION)),
                block.chainid,
                address(this)
            )
        );

        /// @solidity memory-safe-assembly
        assembly {
            function mstore160(offset, value) {
                let lower12 := shr(160, shl(160, mload(offset)))
                mstore(offset, or(lower12, shl(96, value)))
            }

            // build:meth-immutable-start

            // Insert 'meth.immutable.old-weth' into final code.
            mstore160(0x0759, oldWeth)
            mstore160(0x197b, oldWeth)
            mstore160(0x4128, oldWeth)
            mstore160(0x415d, oldWeth)

            // Insert 'meth.immutable.cached-domain-separator' into final code.
            mstore(0x0dcc, domainSeparator)
            mstore(0x35ee, domainSeparator)

            // build:meth-immutable-end

            return(add(code, 0x20), mload(code))
        }
    }
}
