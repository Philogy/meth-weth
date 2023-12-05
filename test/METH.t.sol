// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {METHInjected} from "./base/METHInjected.sol";
import {METHBaseTest} from "./base/METHBaseTest.sol";

/// @author philogy <https://github.com/philogy>
contract METHTest is METHInjected, METHBaseTest {
    function testNonPayableRevertsOnValue() public {
        // View methods
        _testNonPayable(meth.symbol.selector, "");
        _testNonPayable(meth.name.selector, "");
        _testNonPayable(meth.decimals.selector, "");
        _testNonPayable(meth.totalSupply.selector, "");
        _testNonPayable(meth.balanceOf.selector, abi.encode(vm.addr(1)));
        _testNonPayable(meth.allowance.selector, abi.encode(vm.addr(1), vm.addr(2)));

        // Non-view methods
        _testNonPayable(meth.withdraw.selector, abi.encode(uint256(0)));
        _testNonPayable(meth.withdrawTo.selector, abi.encode(vm.addr(3), uint256(0)));
        _testNonPayable(meth.withdrawAll.selector, "");
        _testNonPayable(meth.withdrawAllTo.selector, abi.encode(vm.addr(1)));
        _testNonPayable(meth.transfer.selector, abi.encode(vm.addr(1), uint256(0)));
    }

    function _testNonPayable(bytes4 _selector, bytes memory _addedData) internal {
        bytes memory dataForCall = abi.encodePacked(_selector, _addedData);
        (bool success, bytes memory revertData) = address(meth).call{value: 1 wei}(dataForCall);
        assertFalse(success, "Non-payable function accepted value");
        assertEq(revertData, "", "msg.value revert should be empty");
    }
}
