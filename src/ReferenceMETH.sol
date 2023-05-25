// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IMETH} from "./interfaces/IMETH.sol";
import {METHConstants} from "./METHConstants.sol";

/// @author philogy <https://github.com/philogy>
contract ReferenceMETH is IMETH {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address internal immutable recovery;

    string public constant symbol = "METH";
    string public constant name = "Maximally Efficient Wrapped Ether";
    uint8 public constant decimals = 18;

    constructor(address recovery_) {
        recovery = recovery_;
    }

    function totalSupply() external view returns (uint256) {
        return address(this).balance;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _useAllowance(from, amount);
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function depositTo(address to) external payable {
        unchecked {
            balanceOf[to] += msg.value;
        }
        emit Deposit(to, msg.value);
    }

    function depositAndApprove(address spender, uint256 amount) external {
        deposit();
        approve(spender, amount);
    }

    function withdrawAll() external {
        uint256 amount = balanceOf[msg.sender];
        _withdraw(msg.sender, amount);
        _sendEth(msg.sender, amount);
    }

    function withdrawAllTo(address to) external {
        uint256 amount = balanceOf[msg.sender];
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
        uint256 zeroBal = balanceOf[address(0)];
        uint256 thisBal = balanceOf[address(this)];
        emit Transfer(address(0), recovery, zeroBal);
        emit Transfer(address(this), recovery, thisBal);
        balanceOf[address(0)] = 0;
        balanceOf[address(this)] = 0;
        unchecked {
            balanceOf[recovery] += zeroBal + thisBal;
        }
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount);
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _useAllowance(address owner, uint256 amount) internal {
        if (allowance[owner][msg.sender] < METHConstants.MIN_INF_ALLOWANCE) {
            require(allowance[owner][msg.sender] >= amount);
            allowance[owner][msg.sender] -= amount;
        }
    }

    function _withdraw(address from, uint256 amount) internal {
        uint256 bal = balanceOf[from];
        require(bal >= amount);
        unchecked {
            balanceOf[from] = bal - amount;
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
}
