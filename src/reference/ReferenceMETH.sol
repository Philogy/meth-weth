// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IMETH} from "../interfaces/IMETH.sol";
import {IWETH9} from "../interfaces/IWETH9.sol";
import {MIN_INF_ALLOWANCE} from "../METHConstants.sol";

/// @author philogy <https://github.com/philogy>
contract ReferenceMETH is IMETH {
    address internal immutable recovery;
    IWETH9 internal immutable WETH9;

    string public constant symbol = "METH";
    string public constant name = "Maximally Efficient Wrapped Ether";
    uint8 public constant decimals = 18;

    uint256 public reservesOld;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public balanceOf;

    constructor(address recovery_, address weth9) {
        require(recovery_ != address(0) && recovery_ != address(this));
        recovery = recovery_;
        WETH9 = IWETH9(weth9);
    }

    function transfer(address to, uint256 amount) external {
        _transfer(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) external {
        _useAllowance(from, amount);
        _transfer(from, to, amount);
    }

    function approve(address spender, uint256 amount) public {
        allowance[msg.sender][spender] = amount;
    }

    receive() external payable {
        balanceOf[msg.sender] += msg.value;
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
    }

    function depositTo(address to) external payable {
        balanceOf[to] += msg.value;
    }

    function depositAndApprove(address spender, uint256 amount) external payable {
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
        balanceOf[address(0)] = 0;
        balanceOf[address(this)] = 0;
        unchecked {
            balanceOf[recovery] += zeroBal + thisBal;
        }
    }

    function depositWithOldTo(address to) external {
        uint256 oldWethBal = WETH9.balanceOf(address(this));
        uint256 deposited;
        unchecked {
            deposited = oldWethBal - reservesOld;
            balanceOf[to] += deposited;
        }
        reservesOld = oldWethBal;
    }

    function withdrawAsOldTo(address to, uint256 amount) external {
        uint256 preBal = balanceOf[msg.sender];
        require(preBal >= amount);
        uint256 preReserves = reservesOld;
        unchecked {
            if (amount > preReserves) {
                // If not enough WETH9 already held as reserves
                (bool success,) = address(WETH9).call{value: amount - preReserves}("");
                require(success);
                reservesOld = 0;
            } else {
                reservesOld = preReserves - amount;
            }
            balanceOf[msg.sender] = preBal - amount;
        }
        WETH9.transfer(to, amount);
    }

    function totalSupply() external view returns (uint256) {
        unchecked {
            return address(this).balance + reservesOld;
        }
    }

    function _transfer(address from, address to, uint256 amount) internal {
        uint256 preFromBal = balanceOf[from];
        require(preFromBal >= amount);
        unchecked {
            balanceOf[from] = preFromBal - amount;
            balanceOf[to] += amount;
        }
    }

    function _useAllowance(address owner, uint256 amount) internal {
        uint256 currentAllowance = allowance[owner][msg.sender];
        if (currentAllowance >= MIN_INF_ALLOWANCE) return;
        require(currentAllowance >= amount);
        unchecked {
            allowance[owner][msg.sender] = currentAllowance - amount;
        }
    }

    function _withdraw(address from, uint256 amount) internal {
        uint256 preBal = balanceOf[from];
        require(preBal >= amount);
        unchecked {
            balanceOf[from] = preBal - amount;
        }
    }

    function _sendEth(address to, uint256 amount) internal {
        (bool success,) = to.call{value: amount}("");
        if (!success) {
            /// @solidity memory-safe-assembly
            assembly {
                let free := mload(0x40)
                returndatacopy(free, 0x00, returndatasize())
                revert(free, returndatasize())
            }
        }
    }
}
