// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IERC20} from "./IERC20.sol";

/// @author philogy <https://github.com/philogy>
/// @notice Typically non-payable methods made payable to be compatible with multicall
interface IYAM_WETH {
    /*//////////////////////////////////////////////////////////////
                            ERC2612
    //////////////////////////////////////////////////////////////*/

    function permit(
        address _owner,
        address _spender,
        uint _value,
        uint _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external payable;

    function nonces(address _owner) external view returns (uint);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /*//////////////////////////////////////////////////////////////
                        PRIMARY OPERATOR
    //////////////////////////////////////////////////////////////*/

    event PrimaryOperatorSet(address indexed account, address indexed prevOperator, address indexed newOperator);

    function setPrimaryOperator(address _newOperator) external payable returns (bool success);

    function primaryOperatorOf(address _account) external view returns (address);
}
