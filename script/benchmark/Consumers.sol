// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IMETH} from "../../src/interfaces/IMETH.sol";
import {IWETH9} from "../../src/interfaces/IWETH9.sol";

abstract contract ConsumerBase {
    receive() external payable {}

    function withdrawAll() external virtual;

    function withdrawAllTo(address recipient) external virtual;

    function depositTo(address recipient, uint256 amount) external virtual;
}

/// @author philogy <https://github.com/philogy>
abstract contract MethConsumer is ConsumerBase {}

/// @author philogy <https://github.com/philogy>
abstract contract Weth9Consumer is ConsumerBase {}
