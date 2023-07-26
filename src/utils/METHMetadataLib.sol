// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author philogy <https://github.com/philogy>
library METHMetadataLib {
    error SymbolTooLong();
    error NameTooLong();

    uint256 internal constant MAX_SYMBOL_LENGTH = 31;
    uint256 internal constant MAX_NAME_LENGTH = 64;

    function encodeMetadataContainer(uint8 decimals, string memory symbol, string memory name)
        internal
        pure
        returns (bytes memory)
    {
        uint256 symbolLength = bytes(symbol).length;
        if (symbolLength > MAX_SYMBOL_LENGTH) revert SymbolTooLong();
        uint256 nameLength = bytes(name).length;
        if (nameLength > MAX_NAME_LENGTH) revert NameTooLong();
        bytes memory padding = nameLength > 32
            ? bytes(hex"")
            : bytes(hex"0000000000000000000000000000000000000000000000000000000000000000");
        return abi.encodePacked(
            bytes1(0x00), // STOP Padding
            decimals,
            uint8(symbolLength),
            bytes31(bytes(symbol)),
            abi.encode(name),
            padding
        );
    }
}
