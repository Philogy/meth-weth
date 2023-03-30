// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IMETH} from "./interfaces/IMETH.sol";

/// @author philogy <https://github.com/philogy>
contract ReferenceMETH is IMETH {
    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public nonces;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 internal constant MIN_INF_ALLOW = 0xff00000000000000000000000000000000000000000000000000000000000000;
    uint256 internal constant CHAIN_ID = 0x1;

    address internal immutable recovery;

    string public constant symbol = "METH";
    string public constant name = "Maximally Efficient Wrapped Ether";
    uint8 public constant decimals = 18;
    bytes32 public immutable DOMAIN_SEPARATOR;

    constructor(address _recovery) {
        assert(CHAIN_ID == block.chainid);
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256("1.0"),
                block.chainid,
                address(this)
            )
        );
        recovery = _recovery;
    }

    function totalSupply() external view returns (uint256) {
        return address(this).balance;
    }

    function transfer(address _to, uint256 _amount) external returns (bool) {
        _transfer(msg.sender, _to, _amount);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool) {
        _useAllowance(_from, _amount);
        _transfer(_from, _to, _amount);
        return true;
    }

    function approve(address _spender, uint256 _amount) public returns (bool) {
        allowance[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function depositTo(address _to) external payable {
        balanceOf[_to] += msg.value;
        emit Deposit(_to, msg.value);
    }

    function depositAndApprove(address _spender, uint256 _amount) external {
        deposit();
        approve(_spender, _amount);
    }

    function withdrawAll() external {
        uint256 amount = balanceOf[msg.sender];
        _withdraw(msg.sender, amount);
        _sendEth(msg.sender, amount);
    }

    function withdrawAllTo(address _to) external {
        uint256 amount = balanceOf[msg.sender];
        _withdraw(msg.sender, amount);
        _sendEth(_to, amount);
    }

    function withdraw(uint256 _amount) external {
        _withdraw(msg.sender, _amount);
        _sendEth(msg.sender, _amount);
    }

    function withdrawTo(address _to, uint256 _amount) external {
        _withdraw(msg.sender, _amount);
        _sendEth(_to, _amount);
    }

    function withdrawFrom(address _from, uint256 _amount) external {
        _useAllowance(_from, _amount);
        _withdraw(_from, _amount);
        _sendEth(msg.sender, _amount);
    }

    function withdrawFromTo(address _from, address _to, uint256 _amount) external {
        _useAllowance(_from, _amount);
        _withdraw(_from, _amount);
        _sendEth(_to, _amount);
    }

    function multicall(bytes[] calldata _calls) external returns (bytes[] memory rets) {
        for (uint256 i = 0; i < _calls.length; i++) {
            (bool success, bytes memory ret) = address(this).delegatecall(_calls[i]);
            _bubbleRevert(success);
            rets[i] = ret;
        }
    }

    function permit(
        address _owner,
        address _spender,
        uint256 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        if (block.timestamp > _deadline) revert PermitExpired();

        address originalSigner = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            keccak256(
                                "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                            ),
                            _owner,
                            _spender,
                            _amount,
                            nonces[_owner]++,
                            _deadline
                        )
                    )
                )
            ),
            _v,
            _r,
            _s
        );

        if (originalSigner == address(0) || originalSigner != _owner) revert InvalidSignature();

        allowance[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);
    }

    function rescueLost() external {
        uint256 zeroBal = balanceOf[address(0)];
        uint256 thisBal = balanceOf[address(this)];
        emit Transfer(address(0), recovery, zeroBal);
        emit Transfer(address(this), recovery, zeroBal);
        balanceOf[address(0)] = 0;
        balanceOf[address(this)] = 0;
        balanceOf[recovery] += zeroBal + thisBal;
    }

    function _transfer(address _from, address _to, uint256 _amount) internal {
        if (balanceOf[_from] < _amount) revert InsufficientBalance();
        balanceOf[_from] -= _amount;
        balanceOf[_to] += _amount;
        emit Transfer(_from, _to, _amount);
    }

    function _useAllowance(address _owner, uint256 _amount) internal {
        if (allowance[_owner][msg.sender] < MIN_INF_ALLOW) {
            if (allowance[_owner][msg.sender] < _amount) revert InsufficientAllowance();
            allowance[_owner][msg.sender] -= _amount;
        }
    }

    function _withdraw(address _from, uint256 _amount) internal {
        if (balanceOf[_from] < _amount) revert InsufficientBalance();
        balanceOf[_from] -= _amount;
        emit Withdrawal(_from, _amount);
    }

    function _sendEth(address _to, uint256 _amount) internal {
        (bool success,) = _to.call{value: _amount}("");
        _bubbleRevert(success);
    }

    function _bubbleRevert(bool _success) internal {
        if (!_success) {
            assembly {
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
        }
    }
}
