// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

///
/**
 * @author philogy <https://github.com/philogy>
 * @dev Contract that puts together the initial runtime code for METH.
 */
interface ILab {
    /**
     * @dev Expected to directly return desired bytecode
     */
    function getFinalProduct() external;
}
