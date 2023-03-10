// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IERC20} from "./IERC20.sol";

/// @author philogy <https://github.com/philogy>
interface IWETH9 is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;

    event Deposit(address indexed to, uint256 amount);
    event Withdrawal(address indexed from, uint256 amount);
}
