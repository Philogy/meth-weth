// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";

/// @author philogy <https://github.com/philogy>
contract HuffDeployer is Test {
    function deploy(string memory _path) public returns (address created) {
        return deploy(_path, new string[](0), 0);
    }

    function deploy(string memory _path, uint256 _value) public returns (address created) {
        return deploy(_path, new string[](0), _value);
    }

    function deploy(string memory _path, string[] memory _constants, uint256 _value) public returns (address created) {
        bytes memory out = getBytecode(_path, _constants);
        assembly {
            created := create(_value, add(out, 0x20), mload(out))
        }
        require(created != address(0));
    }

    function getBytecode(string memory _path, string[] memory _constants) public returns (bytes memory) {
        string[] memory inputs = new string[](3 + _constants.length * 2);
        inputs[0] = "huffc";
        inputs[1] = _path;
        inputs[2] = "-b";
        for (uint256 i = 0; i < _constants.length; i++) {
            inputs[3 + i * 2] = "-c";
            inputs[4 + i * 2] = _constants[i];
        }
        return vm.ffi(inputs);
    }
}
