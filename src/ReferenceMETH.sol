// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IMETH} from "./interfaces/IMETH.sol";
import {MIN_INF_ALLOWANCE} from "./METHConstants.sol";

/// @author philogy <https://github.com/philogy>
contract ReferenceMETH is IMETH {
    struct Value {
        uint256 value;
    }

    address internal immutable recovery;

    string public constant symbol = "METH";
    string public constant name = "Maximally Efficient Wrapped Ether";
    uint8 public constant decimals = 18;

    constructor(address recovery_) {
        recovery = recovery_;
    }

    function transfer(address to, uint256 amount) external {
        _transfer(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) external {
        _useAllowance(from, amount);
        _transfer(from, to, amount);
    }

    function approve(address spender, uint256 amount) public {
        _allowance(msg.sender, spender).value = amount;
        emit Approval(msg.sender, spender, amount);
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        unchecked {
            _balanceOf(msg.sender).value += msg.value;
        }
        emit Deposit(msg.sender, msg.value);
    }

    function depositTo(address to) external payable {
        unchecked {
            _balanceOf(to).value += msg.value;
        }
        emit Deposit(to, msg.value);
    }

    function depositAndApprove(address spender, uint256 amount) external payable {
        deposit();
        approve(spender, amount);
    }

    function withdrawAll() external {
        uint256 amount = _balanceOf(msg.sender).value;
        _withdraw(msg.sender, amount);
        _sendEth(msg.sender, amount);
    }

    function withdrawAllTo(address to) external {
        uint256 amount = _balanceOf(msg.sender).value;
        _withdraw(msg.sender, amount);
        _sendEth(to, amount);
    }

    function withdraw(uint256 amount) external {
        _withdraw(msg.sender, amount);
        _sendEth(msg.sender, amount);
    }

    function withdrawTo(address to, uint256 amount) external {
        _withdraw(msg.sender, amount);
        _sendEth(to, amount);
    }

    function withdrawFrom(address from, uint256 amount) external {
        _useAllowance(from, amount);
        _withdraw(from, amount);
        _sendEth(msg.sender, amount);
    }

    function withdrawFromTo(address from, address to, uint256 amount) external {
        _useAllowance(from, amount);
        _withdraw(from, amount);
        _sendEth(to, amount);
    }

    function sweepLost() external {
        uint256 zeroBal = _balanceOf(address(0)).value;
        uint256 thisBal = _balanceOf(address(this)).value;
        emit Transfer(address(0), recovery, zeroBal);
        emit Transfer(address(this), recovery, thisBal);
        _balanceOf(address(0)).value = 0;
        _balanceOf(address(this)).value = 0;
        unchecked {
            _balanceOf(recovery).value += zeroBal + thisBal;
        }
    }

    function totalSupply() external view returns (uint256) {
        return address(this).balance;
    }

    function balanceOf(address acc) external view returns (uint256) {
        return _balanceOf(acc).value;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowance(owner, spender).value;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(_balanceOf(from).value >= amount);
        unchecked {
            _balanceOf(from).value -= amount;
            _balanceOf(to).value += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _useAllowance(address owner, uint256 amount) internal {
        uint256 allowance = _allowance(owner, msg.sender).value;
        if (allowance < MIN_INF_ALLOWANCE) {
            require(allowance >= amount);
            unchecked {
                _allowance(owner, msg.sender).value = allowance - amount;
            }
        }
    }

    function _withdraw(address from, uint256 amount) internal {
        uint256 bal = _balanceOf(from).value;
        require(bal >= amount);
        unchecked {
            _balanceOf(from).value = bal - amount;
        }
        emit Withdrawal(from, amount);
    }

    function _sendEth(address to, uint256 amount) internal {
        (bool success,) = to.call{value: amount}("");
        if (!success) {
            assembly {
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
        }
    }

    function _balanceOf(address acc) internal pure returns (Value storage value) {
        assembly {
            value.slot := acc
        }
    }

    function _allowance(address owner, address spender) internal pure returns (Value storage value) {
        assembly {
            mstore(0x00, owner)
            mstore(0x20, spender)
            value.slot := keccak256(0x00, 0x40)
        }
    }
}
