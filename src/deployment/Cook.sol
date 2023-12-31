// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable} from "solady/auth/Ownable.sol";
import {ICook} from "../interfaces/ICook.sol";
import {CrystallizationTray} from "./CrystallizationTray.sol";

/**
 * @author philogy <https://github.com/philogy>
 * @dev The cook serves as the "factory" for METH, it ensures that the magic salt could be mined in
 * advance of the final bytecode being known.
 */
contract Cook is Ownable, ICook {
    address public lab;

    constructor() {
        _initializeOwner(msg.sender);
    }

    function cookWithLab(address lab_, bytes32 salt) external onlyOwner returns (address meth) {
        if (lab != address(0)) revert AlreadyCooked();
        if (lab_ == address(0)) revert ZeroAddress();
        lab = lab_;

        meth = address(new CrystallizationTray{salt: salt}());
    }
}
