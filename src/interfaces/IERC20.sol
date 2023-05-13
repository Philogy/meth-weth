// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

/// @author philogy <https://github.com/philogy>
interface IERC20 {
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

    function transfer(address _to, uint256 _amount) external returns (bool success);

    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool success);

    function approve(address _spender, uint256 _amount) external returns (bool success);
}
