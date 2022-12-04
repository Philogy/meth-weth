// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IERC20} from "../../src/IERC20.sol";

/// @author philogy <https://github.com/philogy>
interface IWETH9 is IERC20 {
    function deposit() external payable;

    function withdraw(uint _amount) external;
}
