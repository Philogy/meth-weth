// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ILab} from "../../src/interfaces/ILab.sol";
import {BytesLib} from "../../src/utils/BytesLib.sol";
import {console2 as console} from "forge-std/console2.sol";

/// @author philogy <https://github.com/philogy>
contract MockLab is ILab {
    using BytesLib for bytes;

    uint256 internal immutable LEN;
    bytes32 internal immutable DATA;

    constructor(bytes memory d) {
        require(d.length <= 32, "d.length > 32");
        LEN = d.length;
        DATA = bytes32(d);
    }

    function data() public view returns (bytes memory) {
        return abi.decode(abi.encode(uint256(0x20), LEN, DATA), (bytes));
    }

    function getFinalProduct() external view {
        data().directReturn();
    }
}
