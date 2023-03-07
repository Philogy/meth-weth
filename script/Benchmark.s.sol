// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {HuffDeployer} from "../test/utils/HuffDeployer.sol";

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

    address internal immutable REC1 = makeAddr("rec1");

    function run() public {
        vm.startBroadcast(vm.envUint("PRIV_KEY"));

        _runOn(IWETH(WETH9));
        _runOn(IWETH(METH));

        vm.stopBroadcast();
    }

    function _runOn(IWETH _weth) internal {
        _weth.deposit{value: 1 wei}();
        _weth.transfer(REC1, 1 wei);
        address(_weth).call{value: 1 wei}("");
    }
}
