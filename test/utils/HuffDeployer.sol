// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";

/// @author philogy <https://github.com/philogy>
contract HuffDeployer is Test {
    function deploy(string memory _path, string[] memory _constants, uint _value) external returns (address created) {
        string[] memory inputs = new string[](3 + _constants.length * 2);
        inputs[0] = "huffc";
        inputs[1] = _path;
        inputs[2] = "-b";
        for (uint i = 0; i < _constants.length; i++) {
            inputs[3 + i * 2] = "-c";
            inputs[4 + i * 2] = _constants[i];
        }
        bytes memory out = vm.ffi(inputs);
        assembly {
            created := create(_value, add(out, 0x20), mload(out))
        }
        require(created != address(0));
    }
}
