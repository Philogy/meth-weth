// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @author philogy <https://github.com/philogy>
contract Reverter {
    bytes internal revertdata;

    constructor(bytes memory _revertdata) {
        revertdata = _revertdata;
    }

    function setRevert(bytes calldata _revertdata) external {
        revertdata = _revertdata;
    }

    receive() external payable {
        _revert();
    }

    fallback() external {
        _revert();
    }

    function _revert() internal view {
        bytes memory revertdataRef = revertdata;
        assembly {
            revert(add(revertdataRef, 0x20), mload(revertdataRef))
        }
    }
}
