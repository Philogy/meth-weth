// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ICook} from "../interfaces/ICook.sol";
import {ILab} from "../interfaces/ILab.sol";
import {IMETH} from "../interfaces/IMETH.sol";
import {MockMETH} from "../../test/mocks/MockMETH.sol";
import {BytesLib} from "../utils/BytesLib.sol";

/**
 * @author philogy <https://github.com/philogy>
 * @dev Contract that actually deploys the final METH bytecode. Retrieves the bytecode from an
 * external source to ensure that its address is independent of the runtime code.
 */
contract CrystallizationTray is IMETH, MockMETH {
    using BytesLib for bytes;

    error FailedToRetrieveCode();
    error NoLab();
    error NoRuntimeReturned();

    constructor() {
        address lab = ICook(msg.sender).lab();
        if (lab == address(0) || lab.code.length == 0) revert NoLab();
        // Delegatecall allows lab to make initializing state mutations if necessary.
        (bool success, bytes memory runtime) = lab.delegatecall(abi.encodeCall(ILab.getFinalProduct, ()));
        if (!success) revert FailedToRetrieveCode();
        if (runtime.length == 0) revert NoRuntimeReturned();

        runtime.directReturn();
    }
}
