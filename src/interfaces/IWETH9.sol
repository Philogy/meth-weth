// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Metadata} from "./IERC20Metadata.sol";

/// @author philogy <https://github.com/philogy>
interface IWETH9 is IERC20Metadata {
    ////////////////////////////////////////////////////////////////
    //                           ERC20                            //
    ////////////////////////////////////////////////////////////////

    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function totalSupply() external view returns (uint256);

    function balanceOf(address _owner) external view returns (uint256);

    function allowance(address _owner, address _spender) external view returns (uint256);

    function transfer(address _to, uint256 _amount) external returns (bool success);

    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool success);

    function approve(address _spender, uint256 _amount) external returns (bool success);

    ////////////////////////////////////////////////////////////////
    //                           WETH9                            //
    ////////////////////////////////////////////////////////////////

    function deposit() external payable;
    function withdraw(uint256) external;

    event Deposit(address indexed to, uint256 amount);
    event Withdrawal(address indexed from, uint256 amount);
}
