// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @author philogy <https://github.com/philogy>
/// @notice Typically non-payable methods made payable to be compatible with multicall
interface IYAM_WETH {
    /*//////////////////////////////////////////////////////////////
                         ERC20 METADATA
    //////////////////////////////////////////////////////////////*/

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    /*//////////////////////////////////////////////////////////////
                           ERC20 CORE
    //////////////////////////////////////////////////////////////*/

    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function totalSupply() external view returns (uint256);

    function balanceOf(address _owner) external view returns (uint256);

    function allowance(address _owner, address _spender) external view returns (uint256);

    function transfer(address _to, uint256 _amount) external payable returns (bool success);

    function transferFrom(address _from, address _to, uint256 _amount) external payable returns (bool success);

    function approve(address _spender, uint256 _amount) external payable returns (bool success);

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
