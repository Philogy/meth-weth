// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import {IERC20Metadata} from "./IERC20Metadata.sol";

/// @author philogy <https://github.com/philogy>
interface IMETH is IERC20Metadata {
    ////////////////////////////////////////////////////////////////
    //                           ERC20                            //
    ////////////////////////////////////////////////////////////////

    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function totalSupply() external view returns (uint256);

    function balanceOf(address _owner) external view returns (uint256);

    function allowance(address _owner, address _spender) external view returns (uint256);

    function transfer(address _to, uint256 _amount) external;

    function transferFrom(address _from, address _to, uint256 _amount) external;

    function approve(address _spender, uint256 _amount) external;

    ////////////////////////////////////////////////////////////////
    //                       WRAPPED ETHER                        //
    ////////////////////////////////////////////////////////////////

    event Deposit(address indexed to, uint256 amount);

    function deposit() external payable;

    function depositTo(address _to) external payable;

    function depositAndApprove(address _spender, uint256 _amount) external payable;

    event Withdrawal(address indexed from, uint256 amount);

    function withdraw(uint256 _amount) external;

    function withdrawTo(address _to, uint256 _amount) external;

    function withdrawAll() external;

    function withdrawAllTo(address) external;

    function withdrawFrom(address _from, uint256 _amount) external;

    function withdrawFromTo(address _from, address _to, uint256 _amount) external;

    /*//////////////////////////////////////////////////////////////
                            UTILITY
    //////////////////////////////////////////////////////////////*/

    function sweepLost() external;
}
