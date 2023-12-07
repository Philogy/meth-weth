// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {WETH} from "solady/tokens/WETH.sol";
import {MockMETH} from "../mocks/MockMETH.sol";
import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";

/// @author philogy <https://github.com/philogy>
contract METHBase is Test {
    using stdStorage for StdStorage;

    WETH immutable weth = new WETH();
    address immutable recovery = makeAddr("RECOVERY");
    address internal immutable __methDealer = makeAddr("__methDealer");
    MockMETH immutable meth = new MockMETH();

    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    StdStorage private storer;

    constructor() {
        vm.label(address(meth), "METH");
    }

    function dealMeth(address to, uint256 amount) internal {
        uint256 balBefore = __methDealer.balance;
        hoax(__methDealer, amount);
        meth.depositTo{value: amount}(to);
        vm.deal(__methDealer, balBefore);
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }

    function max(uint256 x, uint256 y) internal pure returns (uint256) {
        return x > y ? x : y;
    }

    function reservesOld() internal view returns (uint256) {
        return meth.totalSupply() - address(meth).balance;
    }

    function _setNonce(address nonce, uint256 newNonce) internal {
        storer.target(address(meth)).sig(MockMETH.nonces.selector).with_key(nonce).checked_write(newNonce);
    }

    function _signPermit(Account memory account, address spender, uint256 amount, uint256 nonce, uint256 deadline)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 innerHash = keccak256(abi.encode(PERMIT_TYPEHASH, account.addr, spender, amount, nonce, deadline));
        bytes32 domainSeparator = meth.DOMAIN_SEPARATOR();
        bytes32 outerHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, innerHash));
        (v, r, s) = vm.sign(account.key, outerHash);
    }
}
