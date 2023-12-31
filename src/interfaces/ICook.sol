// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author philogy <https://github.com/philogy>
interface ICook {
    error AlreadyCooked();
    error ZeroAddress();

    function lab() external view returns (address);

    function cookWithLab(address lab_, bytes32 salt) external returns (address meth);
}
