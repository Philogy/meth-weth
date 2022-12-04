// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IERC3156FlashBorrower} from "../../../src/flashloan/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "../../../src/flashloan/IERC3156FlashLender.sol";

/// @author philogy <https://github.com/philogy>
contract Borrower is IERC3156FlashBorrower {
    address public lastInitiator;
    address public lastToken;
    uint256 public lastAmount;
    uint256 public lastFee;
    bytes public lastData;

    address checkCallDest;
    bytes checkCall;

    function setupCheck(address _checker, bytes calldata _checkdata) external {
        checkCallDest = _checker;
        checkCall = _checkdata;
    }

    function flashmint(
        address _weth,
        address _receiver,
        address _token,
        uint _amount,
        bytes calldata _data
    ) external returns (bool) {
        return IERC3156FlashLender(_weth).flashLoan(_receiver, _token, _amount, _data);
    }

    function onFlashLoan(
        address _initiator,
        address _token,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _data
    ) external returns (bytes32) {
        lastInitiator = _initiator;
        lastToken = _token;
        lastAmount = _amount;
        lastFee = _fee;
        lastData = _data;

        if (checkCallDest != address(0)) {
            (bool success, ) = checkCallDest.call(checkCall);
            assembly {
                if iszero(success) {
                    returndatacopy(0, 0, returndatasize())
                    return(0, returndatasize())
                }
            }
        }

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
