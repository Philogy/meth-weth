// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import {IERC20} from "./IERC20.sol";

/// @author philogy <https://github.com/philogy>
interface IMETH is IERC20 {
    /*//////////////////////////////////////////////////////////////
                        WRAPPED ETHER
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed to, uint256 amount);

    function deposit() external payable;

    function depositTo(address _to) external payable;

    function depositAndApprove(address _spender, uint256 _amount) external;

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
