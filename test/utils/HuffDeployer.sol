// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

enum CodeType {
    Runtime,
    Deployment
}

/// @author philogy <https://github.com/philogy>
library HuffDeployer {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function deploy(string memory _path) internal returns (address created) {
        return deploy(_path, new string[](0), 0);
    }

    function deploy(string memory _path, uint256 _value) internal returns (address created) {
        return deploy(_path, new string[](0), _value);
    }

    function deploy(string memory _path, string[] memory _constants, uint256 _value)
        internal
        returns (address created)
    {
        bytes memory out = getBytecode(CodeType.Deployment, _path, _constants);
        assembly {
            created := create(_value, add(out, 0x20), mload(out))
        }
        require(created != address(0), "ERROR_IN_CONSTRUCTOR");
    }

    function getBytecode(CodeType codeType, string memory _path, string[] memory _constants)
        internal
        returns (bytes memory)
    {
        string[] memory inputs = new string[](3 + _constants.length * 2);
        inputs[0] = "huffy";
        inputs[1] = _path;
        inputs[2] = codeType == CodeType.Deployment ? "-b" : "-r";
        for (uint256 i = 0; i < _constants.length; i++) {
            inputs[3 + i * 2] = "-c";
            inputs[4 + i * 2] = _constants[i];
        }
        return vm.ffi(inputs);
    }
}
