// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author philogy <https://github.com/philogy>
library BytesLib {
    function directReturn(bytes memory data) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            return(add(data, 0x20), mload(data))
        }
    }
}
