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

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function transfer(address to, uint256 amount) external;

    function transferFrom(address from, address to, uint256 amount) external;

    function approve(address spender, uint256 amount) external;

    ////////////////////////////////////////////////////////////////
    //                          ERC2612                           //
    ////////////////////////////////////////////////////////////////

    function nonces(address owner) external view returns (uint256);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    ////////////////////////////////////////////////////////////////
    //                       WRAPPED ETHER                        //
    ////////////////////////////////////////////////////////////////

    event Deposit(address indexed to, uint256 amount);

    function deposit() external payable;

    function depositTo(address to) external payable;

    function depositAndApprove(address spender, uint256 amount) external payable;

    event Withdrawal(address indexed from, uint256 amount);

    function withdraw(uint256 amount) external;

    function withdrawTo(address to, uint256 amount) external;

    function withdrawAll() external;

    function withdrawAllTo(address) external;

    function withdrawFrom(address from, uint256 amount) external;

    function withdrawFromTo(address from, address to, uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                            UTILITY
    //////////////////////////////////////////////////////////////*/

    function sweepLost() external;

    function depositWithOldTo(address to) external;

    function withdrawAsOldTo(address to, uint256 amount) external;

    function reservesOld() external view returns (uint256);

    event DepositWithOld(address indexed to, uint256 amount);

    event WithdrawAsOld(address indexed from);
}
