// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {METHBaseTest} from "./base/METHBaseTest.sol";
import {ReferenceMETH} from "src/reference/ReferenceMETH.sol";

/// @author philogy <https://github.com/philogy>
contract ReferenceMETHTest is METHBaseTest {
    function setUp() public {
        _setUp(address(new ReferenceMETH(recovery, address(weth))));
    }
}
