// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {HuffDeployer} from "foundry-huff/HuffDeployer.sol";
import {IYAM_WETH} from "../src/interfaces/IYAM_WETH.sol";

/// @author philogy <https://github.com/philogy>
contract YAM_WETHTest is Test {
    IYAM_WETH weth;

    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Deposit(address indexed to, uint256 amount);
    event Withdrawal(address indexed from, uint256 amount);

    function setUp() public {
        vm.chainId(1);
        uint snapshot = vm.snapshot();
        address nextContractAddr = HuffDeployer.deploy("test/Empty");
        vm.revertTo(snapshot);

        address newDeployedWeth = HuffDeployer
            .config()
            .with_bytes32_constant("CACHED_DOMAIN_SEPARATOR", _getDomainSeparator(nextContractAddr))
            .deploy("YAM_WETH");
        weth = IYAM_WETH(newDeployedWeth);
    }

    modifier realAddr(address _a) {
        vm.assume(_a != address(0));
        _;
    }

    function testDeposit(address _owner, uint128 _x) public realAddr(_owner) {
        vm.deal(_owner, _x);
        vm.prank(_owner);
        vm.expectEmit(true, true, true, true);
        emit Deposit(_owner, _x);
        weth.deposit{value: _x}();
        assertEq(weth.balanceOf(_owner), _x);
        assertEq(weth.nonces(_owner), 0);
    }

    function testDepositTo(address _from, address _to, uint128 _x) public realAddr(_from) realAddr(_to) {
        vm.deal(_from, _x);
        vm.prank(_from);
        vm.expectEmit(true, true, true, true);
        emit Deposit(_to, _x);
        weth.depositTo{value: _x}(_to);
        assertEq(weth.balanceOf(_to), _x);
        assertEq(weth.nonces(_to), 0);
    }

    function _getDomainSeparator(address _weth) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256("Yet Another Maximized Wrapped Ether Contract"),
                    keccak256("1"),
                    uint(1),
                    _weth
                )
            );
    }
}
