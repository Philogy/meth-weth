// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {IERC20} from "../../src/interfaces/IERC20.sol";
import {HuffDeployer} from "../../test/utils/HuffDeployer.sol";
import {IMETH} from "../../src/interfaces/IMETH.sol";

// Base interface
interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;

    event Deposit(address indexed to, uint256 amount);
    event Withdrawal(address indexed from, uint256 amount);
}

/// @author philogy <https://github.com/philogy>
contract BenchmarkScript is Test, Script {
    address internal constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant METH = 0x1dA76A96392A9C23228Fa8C11b33aBF4d8B74868;

    uint256 internal constant TEST_PKEY1 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    address internal immutable REC1 = makeAddr("rec1");

    function run() public {
        _runOn(IWETH(WETH9));
        _runOn(IWETH(METH));
    }

    function _runOn(IWETH _weth) internal {
        uint256 mainPkey = vm.envUint("PRIV_KEY");
        vm.startBroadcast(mainPkey);

        _weth.deposit{value: 20 wei}();
        _weth.transfer(vm.addr(TEST_PKEY1), 1 wei);
        address(_weth).call{value: 1 wei}("");
        _weth.approve(vm.addr(TEST_PKEY1), type(uint256).max);
        _weth.withdraw(5 wei);
        vm.stopBroadcast();

        vm.startBroadcast(TEST_PKEY1);
        _weth.transferFrom(vm.addr(mainPkey), vm.addr(TEST_PKEY1), 3 wei);
        vm.stopBroadcast();

        uint fullTransferFromAmount = 5 wei;
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
