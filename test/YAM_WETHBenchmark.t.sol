// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {YAM_WETH} from "../src/YetAnotherMaximizedWETH.sol";
import {IWETH9} from "./mocks/IWETH9.sol";

/// @author philogy <https://github.com/philogy>
contract YAM_WETHBenchmarkTest is Test {
    YAM_WETH internal immutable weth;

    address internal immutable permit2 = vm.addr(0x929829);
    address internal immutable globUser1 = vm.addr(0xacacacacacacacacacacacacacacacac);
    address internal immutable globUser2 = vm.addr(0xbbbbacacacacacacacacacacacacacac);

    IWETH9 internal constant WETH9 = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    modifier pranking(address _account) {
        vm.startPrank(_account);
        _;
        vm.stopPrank();
    }

    constructor() {
        vm.selectFork(vm.createFork(vm.envString("RPC_URL"), vm.envUint("FORK_BLOCK")));

        weth = new YAM_WETH(permit2);
        vm.deal(globUser1, 100_000 ether);
        vm.deal(globUser2, 300_000 ether);
        vm.prank(globUser2);
        weth.deposit{value: 100_000 ether}();
        vm.prank(globUser2);
        WETH9.deposit{value: 100_000 ether}();
    }

    function testDepositToFreshWeth9() public pranking(globUser1) {
        uint amount = 23.0e18;
        WETH9.deposit{value: amount}();
        WETH9.transfer(vm.addr(1), amount);
    }

    function testDepositToFreshYAMWETH() public pranking(globUser1) {
        uint amount = 23.0e18;
        weth.depositTo{value: amount}(vm.addr(1));
    }

    function testDepositToExistingWeth9() public pranking(globUser1) {
        uint amount = 23.0e18;
        WETH9.deposit{value: amount}();
        WETH9.transfer(globUser2, amount);
    }

    function testDepositToExistingYAMWETH() public pranking(globUser1) {
        uint amount = 23.0e18;
        weth.depositTo{value: amount}(globUser2);
    }
}
