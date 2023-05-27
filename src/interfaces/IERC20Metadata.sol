// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

/// @author philogy <https://github.com/philogy>
interface IERC20Metadata {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}
