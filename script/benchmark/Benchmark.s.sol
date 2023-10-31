// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {HuffDeployer} from "test/utils/HuffDeployer.sol";
import {IMETH} from "../../src/interfaces/IMETH.sol";
import {IWETH9} from "../../src/interfaces/IWETH9.sol";

/// @author philogy <https://github.com/philogy>
contract BenchmarkScript is Test, Script {
    address internal constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant METH = 0x91DD230D11BD6640ad29C355f155a9a3C5a75b87;

    uint256 internal constant TEST_PKEY1 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    address internal immutable REC1 = makeAddr("rec1");

    function run() public {
        _runOn(IMETH(WETH9));
        _runOn(IMETH(METH));
    }

    function _runOn(IMETH _weth) internal {
        uint256 mainPkey = vm.envUint("PRIV_KEY");
        vm.startBroadcast(mainPkey);

        _weth.deposit{value: 20 wei}();
        _weth.transfer(vm.addr(TEST_PKEY1), 1 wei);
        address(_weth).call{value: 1 wei}("");
        if (address(_weth) == WETH9) {
            _weth.approve(vm.addr(TEST_PKEY1), type(uint256).max);
        } else {
            address(_weth).call(
                abi.encodePacked(_weth.approve.selector, uint256(uint160(vm.addr(TEST_PKEY1))), uint8(0xff))
            );
        }
        _weth.withdraw(5 wei);
        vm.stopBroadcast();

        vm.startBroadcast(TEST_PKEY1);
        _weth.transferFrom(vm.addr(mainPkey), vm.addr(TEST_PKEY1), 3 wei);
        vm.stopBroadcast();

        uint256 fullTransferFromAmount = 5 wei;
        vm.startBroadcast(mainPkey);
        _weth.approve(vm.addr(TEST_PKEY1), fullTransferFromAmount);
        vm.stopBroadcast();

        vm.startBroadcast(TEST_PKEY1);
        _weth.transferFrom(vm.addr(mainPkey), vm.addr(TEST_PKEY1), fullTransferFromAmount);
        vm.stopBroadcast();

        vm.startBroadcast(mainPkey);

        emit log_named_uint("_weth.balanceOf(vm.addr(mainPkey))", _weth.balanceOf(vm.addr(mainPkey)));

        if (address(_weth) == WETH9) {
            _weth.withdraw(_weth.balanceOf(vm.addr(mainPkey)));
        } else {
            IMETH(address(_weth)).withdrawAll();
        }
        vm.stopBroadcast();
    }
}
