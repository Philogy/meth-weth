// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {HuffDeployer} from "./utils/HuffDeployer.sol";
import {IMETH} from "../src/interfaces/IMETH.sol";
import {LibString} from "solady/utils/LibString.sol";

/// @author philogy <https://github.com/philogy>
contract METH_WETHTest is Test {
    uint internal constant MAINNET_CHAIN_ID = 0x1;

    IMETH meth;

    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Deposit(address indexed to, uint256 amount);
    event Withdrawal(address indexed from, uint256 amount);

    function setUp() public {
        vm.chainId(MAINNET_CHAIN_ID);

        HuffDeployer huffDeployer = new HuffDeployer();

        uint snapshot = vm.snapshot();
        address nextContractAddr = huffDeployer.deploy("./src/test/Empty.huff", new string[](0), 0);
        vm.revertTo(snapshot);

        string[] memory consts = new string[](1);
        consts[0] = string(
            abi.encodePacked(
                "CACHED_DOMAIN_SEPARATOR=",
                LibString.toHexString(uint(_getDomainSeparator(nextContractAddr)), 32)
            )
        );

        meth = IMETH(huffDeployer.deploy("./src/METH_WETH.huff", consts, 0));
    }

    modifier realAddr(address _a) {
        vm.assume(_a != address(0));
        _;
    }


    function testDeposit_fuzzing(address _owner, uint128 _x) public realAddr(_owner) {
        vm.deal(_owner, _x);
        vm.prank(_owner);
        vm.expectEmit(true, true, true, true);
        emit Deposit(_owner, _x);
        meth.deposit{value: _x}();
        assertEq(meth.balanceOf(_owner), _x);
        assertEq(meth.nonces(_owner), 0);
    }

    function testDepositTo_fuzzing(address _from, address _to, uint128 _x) public realAddr(_from) realAddr(_to) {
        vm.deal(_from, _x);
        vm.prank(_from);
        vm.expectEmit(true, true, true, true);
        emit Deposit(_to, _x);
        meth.depositTo{value: _x}(_to);
        assertEq(meth.balanceOf(_to), _x);
        assertEq(meth.nonces(_to), 0);
    }

    function _getDomainSeparator(address _weth) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256("Maximally Efficient Wrapped Ether"),
                    keccak256("1.0"),
                    MAINNET_CHAIN_ID,
                    _weth
                )
            );
    }
}
