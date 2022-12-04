// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IYAM_WETH} from "./IYAM_WETH.sol";
import {Multicallable} from "solady/utils/Multicallable.sol";

/// @dev To ensure safety with multicall use of `msg.value` (`callvalue()`) is avoided, instead the
/// available ETH that can be used is determine by the difference between the contract's balance and
/// the total supply.
contract YAM_WETH is IYAM_WETH, Multicallable {
    // keccak256("YAM_WETH.totalSupply") - 1
    bytes32 internal constant TOTAL_SUPPLY_SLOT = 0xd56ede8fae84e89fcc30c580c1e75530f248a337be6f2dd2c582e96a7859b532;

    address public immutable PERMIT2;

    uint internal constant BALANCE_MASK = 0xffffffffffffffffffffffff;
    uint internal constant ADDR_MASK = 0x00ffffffffffffffffffffffffffffffffffffffff;

    bytes32 internal constant TRANSFER_EVENT_SIG = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    bytes32 internal constant APPROVAL_EVENT_SIG = 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925;

    bytes32 internal constant PRIMARY_OPERATOR_EVENT_SIG =
        0x887b30d73fc01ab8c24c20c0b64cdd39b55b1e2b705237e4e4945e634e31ba74;

    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 internal constant EIP712_DOMAIN_HASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
    // keccak256("Yet Another Maximized Wrapped Ether Contract")
    bytes32 internal constant NAME_HASH = 0x71ad9062969277156f043087ef6affb03325435a01d7a4ba510de93ca3859a76;
    // keccak256("1")
    bytes32 internal constant VERSION_HASH = 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6;
    bytes32 internal immutable CACHED_DOMAIN_SEPARATOR;
    uint internal immutable CACHED_CHAINID;

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
    bytes32 internal constant PERMIT_TYPE_HASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    address internal constant EC_RECOVER_PRECOMPILE = 0x0000000000000000000000000000000000000001;

    error InsufficientBalance();
    error InsufficientFreeBalance();
    error InsufficientPermission();
    error ZeroAddress();
    error TotalSupplyOverflow();
    error PermitExpired();
    error InvalidSignature();

    modifier succeeds() {
        _;
        assembly {
            mstore(0x00, 1)
            return(0x00, 0x20)
        }
    }

    constructor(address _permit2) {
        PERMIT2 = _permit2;
        CACHED_DOMAIN_SEPARATOR = _computeDomainSeparator();
        CACHED_CHAINID = block.chainid;
    }

    receive() external payable {
        deposit();
    }

    function name() external pure returns (string memory) {
        assembly {
            // "Yet Another Maximized Wrapped Ether Contract" (len: 44)
            mstore(0x4c, 0x68657220436f6e7472616374)
            mstore(0x40, 0x59657420416e6f74686572204d6178696d697a65642057726170706564204574)
            mstore(0x20, 0x2c)
            mstore(0x00, 0x20)
            return(0x00, 0x80)
        }
    }

    function symbol() external pure returns (string memory) {
        assembly {
            // "WETH"
            mstore(0x24, 0x57455448)
            mstore(0x20, 0x04)
            mstore(0x00, 0x20)
            return(0x00, 0x60)
        }
    }

    function version() external pure returns (string memory) {
        assembly {
            // "1"
            mstore(0x00, 0x20)
            mstore(0x21, 0x0131)
            return(0x00, 0x60)
        }
    }

    function decimals() external pure returns (uint8) {
        assembly {
            mstore(0x00, 0x12)
            return(0x00, 0x20)
        }
    }

    function approve(address _spender, uint _allowance) external payable succeeds returns (bool) {
        assembly {
            mstore(0x00, caller())
            mstore(0x20, _spender)
            sstore(keccak256(0x00, 0x40), _allowance)
            mstore(0x00, _allowance)
            log3(0x00, 0x20, APPROVAL_EVENT_SIG, caller(), _spender)
        }
    }

    function setPrimaryOperator(address _newOperator) external payable succeeds returns (bool) {
        assembly {
            let callerData := sload(caller())
            let prevOperator := shr(96, callerData)
            sstore(caller(), or(shl(96, _newOperator), and(callerData, BALANCE_MASK)))
            log4(0x00, 0x00, PRIMARY_OPERATOR_EVENT_SIG, caller(), prevOperator, _newOperator)
        }
    }

    function transfer(address _to, uint _amount) external payable succeeds returns (bool) {
        _transfer(_getData(msg.sender), msg.sender, _to, _amount);
    }

    function transferFrom(address _from, address _to, uint _amount) external payable succeeds returns (bool) {
        bytes32 fromData = _useAllowance(_from, _amount);
        _transfer(fromData, _from, _to, _amount);
    }

    function deposit() public payable succeeds returns (bool) {
        _depositAllTo(msg.sender);
    }

    function depositTo(address _recipient) external payable succeeds returns (bool) {
        _depositAllTo(_recipient);
    }

    function depositToMany(address[] calldata _recipients, uint _amount) external payable succeeds returns (bool) {
        assembly {
            let recipientOffset := _recipients.offset
            let totalRecipients := _recipients.length
            let totalAmount := mul(totalRecipients, _amount)

            // `totalAmount` overflow check
            let hasErrors := iszero(eq(div(totalAmount, _amount), totalRecipients))
            mstore(0x00, _amount)
            // prettier-ignore
            for { let pos := shl(5, totalRecipients) } pos {} {
                pos := sub(pos, 0x20)
                let recipient := calldataload(add(recipientOffset, pos))
                hasErrors := or(hasErrors, or(iszero(recipient), sub(recipient, and(recipient, ADDR_MASK))))
                sstore(recipient, add(sload(recipient), _amount))
                log3(0x00, 0x20, TRANSFER_EVENT_SIG, 0, recipient)
            }
            if hasErrors {
                revert(0x00, 0x00)
            }

            // totalSupply checks and updates
            let prevTotalSupply := sload(TOTAL_SUPPLY_SLOT)
            let newTotalSupply := add(prevTotalSupply, totalAmount)
            if or(gt(newTotalSupply, BALANCE_MASK), lt(newTotalSupply, prevTotalSupply)) {
                // `revert TotalSupplyOverflow()`
                mstore(0x00, 0xe5cfe957)
                revert(0x1c, 0x04)
            }
            if gt(newTotalSupply, selfbalance()) {
                // `revert InsufficientFreeBalance()`
                mstore(0x00, 0xa3bf9d5b)
                revert(0x1c, 0x04)
            }
            sstore(TOTAL_SUPPLY_SLOT, newTotalSupply)
        }
    }

    struct Deposit {
        address recipient;
        uint amount;
    }

    function depositAmountsToMany(Deposit[] calldata _deposits) external payable succeeds returns (bool) {
        assembly {
            let depositsOffset := _deposits.offset
            let totalDeposits := _deposits.length

            let prevDepositTotal := 0
            let depositTotal := 0

            let hasErrors := 0
            // prettier-ignore
            for { let pos := shl(6, totalDeposits) } pos {} {
                pos := sub(pos, 0x40)
                prevDepositTotal := depositTotal
                let recipient := calldataload(add(depositsOffset, pos))
                let amount := calldataload(add(depositsOffset, add(pos, 0x20)))
                depositTotal := add(depositTotal, amount)
                // Checks that `depositTotal += amount` did not overflow and that recipient is
                // a valid, non-zero address
                hasErrors := or(
                    hasErrors,
                    or(
                        gt(prevDepositTotal, depositTotal),
                        or(sub(recipient, and(recipient, ADDR_MASK)), iszero(recipient))
                    )
                )
                sstore(recipient, add(sload(recipient), amount))
                mstore(0x00, amount)
                log3(0x00, 0x20, TRANSFER_EVENT_SIG, 0, recipient)
            }
            if hasErrors {
                revert(0x00, 0x00)
            }

            // totalSupply checks and updates
            let prevTotalSupply := sload(TOTAL_SUPPLY_SLOT)
            let newTotalSupply := add(prevTotalSupply, depositTotal)
            if or(gt(newTotalSupply, BALANCE_MASK), lt(newTotalSupply, prevTotalSupply)) {
                // `revert TotalSupplyOverflow()`
                mstore(0x00, 0xe5cfe957)
                revert(0x1c, 0x04)
            }
            if gt(newTotalSupply, selfbalance()) {
                // `revert InsufficientFreeBalance()`
                mstore(0x00, 0xa3bf9d5b)
                revert(0x1c, 0x04)
            }
            sstore(TOTAL_SUPPLY_SLOT, newTotalSupply)
        }
    }

    function withdraw(uint _amount) external payable succeeds returns (bool) {
        _withdrawTo(msg.sender, _amount);
    }

    function withdrawTo(address _to, uint _amount) external payable succeeds returns (bool) {
        _withdrawTo(_to, _amount);
    }

    function withdrawFrom(address _from, uint _amount) external payable succeeds returns (bool) {
        _withdrawFromTo(_from, msg.sender, _amount);
    }

    function withdrawFromTo(address _from, address _to, uint _amount) external payable succeeds returns (bool) {
        _withdrawFromTo(_from, _to, _amount);
    }

    function permit(
        address _owner,
        address _spender,
        uint _allowance,
        uint _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external payable {
        bytes32 domainSeparator = DOMAIN_SEPARATOR();
        assembly {
            if gt(timestamp(), _deadline) {
                // `revert PermitExpired()`
                mstore(0x00, 0x1a15a3cc)
                revert(0x1c, 0x04)
            }

            // Prepare main permit fields.
            mstore(0x00, PERMIT_TYPE_HASH)
            mstore(0x20, _owner)
            mstore(0x40, _spender)
            mstore(0x60, _allowance)
            mstore(0xa0, _deadline)

            // Use nonce.
            let nonceSlot := shl(96, _owner)
            let nonce := sload(nonceSlot)
            sstore(nonceSlot, add(nonce, 1))
            mstore(0x80, nonce)

            let permitStructHash := keccak256(0x00, 0xc0)

            // Change allowance before necessary memory values overwritten.
            let allowanceSlot := keccak256(0x20, 0x40)
            sstore(allowanceSlot, _allowance)
            log3(0x60, 0x20, APPROVAL_EVENT_SIG, _owner, _spender)

            // Calculate final encoded struct hash.
            mstore(0x00, 0x1901)
            mstore(0x20, domainSeparator)
            mstore(0x40, permitStructHash)
            let encodedStruct := keccak256(0x1e, 0x42)

            // Perform ecrecover.
            mstore(0x00, encodedStruct)
            mstore(0x20, _v)
            mstore(0x40, _r)
            mstore(0x60, _s)
            pop(staticcall(gas(), EC_RECOVER_PRECOMPILE, 0x00, 0x80, 0x00, 0x20))
            let recoveredSigner := mload(0x00)

            if iszero(and(eq(returndatasize(), 0x20), eq(recoveredSigner, _owner))) {
                // `revert InvalidSignature()`
                mstore(0x00, 0x8baa579f)
                revert(0x1c, 0x04)
            }

            stop()
        }
    }

    function balanceOf(address _account) external view returns (uint) {
        assembly {
            let bal := and(sload(_account), BALANCE_MASK)
            mstore(0x00, bal)
            return(0x00, 0x20)
        }
    }

    function allowance(address _account, address _spender) external view returns (uint) {
        assembly {
            mstore(0x00, _account)
            mstore(0x20, _spender)
            mstore(0x00, sload(keccak256(0x00, 0x40)))
            return(0x00, 0x20)
        }
    }

    function totalSupply() external view returns (uint) {
        assembly {
            mstore(0x00, sload(TOTAL_SUPPLY_SLOT))
            return(0x00, 0x20)
        }
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == CACHED_CHAINID ? CACHED_DOMAIN_SEPARATOR : _computeDomainSeparator();
    }

    function primaryOperatorOf(address _account) external view returns (address) {
        assembly {
            let data := sload(_account)
            mstore(0x00, shr(96, data))
            return(0x00, 0x20)
        }
    }

    function nonces(address _account) external view returns (uint) {
        assembly {
            let nonce := sload(shl(96, _account))
            mstore(0x00, nonce)
            return(0x00, 0x20)
        }
    }

    function _depositAllTo(address _to) internal {
        assembly {
            if iszero(_to) {
                // `revert ZeroAddress()`
                mstore(0x00, 0xd92e233d)
                revert(0x1c, 0x04)
            }

            let prevTotalSupply := sload(TOTAL_SUPPLY_SLOT)
            let depositAmount := sub(selfbalance(), prevTotalSupply)
            if gt(selfbalance(), BALANCE_MASK) {
                // `revert TotalSupplyOverflow()`
                mstore(0x00, 0xe5cfe957)
                revert(0x1c, 0x04)
            }
            sstore(TOTAL_SUPPLY_SLOT, selfbalance())
            sstore(_to, add(sload(_to), depositAmount))
            mstore(0x00, depositAmount)
            log3(0x00, 0x20, TRANSFER_EVENT_SIG, 0, _to)
        }
    }

    function _withdrawTo(address _to, uint _amount) internal {
        _withdrawDirectFromTo(_getData(msg.sender), msg.sender, _to, _amount);
    }

    function _withdrawFromTo(address _from, address _to, uint _amount) internal {
        bytes32 fromData = _useAllowance(_from, _amount);
        _withdrawDirectFromTo(fromData, _from, _to, _amount);
    }

    function _transfer(bytes32 _fromData, address _from, address _to, uint _amount) internal {
        assembly {
            if iszero(_to) {
                // `revert ZeroAddress()`
                mstore(0x00, 0xd92e233d)
                revert(0x1c, 0x04)
            }
            if gt(_amount, and(_fromData, BALANCE_MASK)) {
                // `revert InsufficientBalance()`
                mstore(0x00, 0xf4d678b8)
                revert(0x1c, 0x04)
            }
            sstore(_from, sub(_fromData, _amount))
            sstore(_to, add(sload(_to), _amount))
            mstore(0x00, _amount)
            log3(0x00, 0x20, TRANSFER_EVENT_SIG, _from, _to)
        }
    }

    function _useAllowance(address _from, uint _amount) internal returns (bytes32 fromData) {
        address permit2 = PERMIT2;
        assembly {
            fromData := sload(_from)

            if iszero(or(eq(caller(), shr(96, fromData)), eq(caller(), permit2))) {
                // Not primary operator or Permit2, check allowance
                mstore(0x00, _from)
                mstore(0x20, caller())
                let allowanceSlot := keccak256(0x00, 0x40)
                let senderAllowance := sload(allowanceSlot)
                if iszero(eq(senderAllowance, not(0))) {
                    if iszero(_from) {
                        // `revert ZeroAddress()`
                        mstore(0x00, 0xd92e233d)
                        revert(0x1c, 0x04)
                    }
                    // No infinite approval
                    if gt(_amount, senderAllowance) {
                        // `revert InsufficientPermission()`
                        mstore(0x00, 0xdeda9030)
                        revert(0x1c, 0x04)
                    }
                    sstore(allowanceSlot, sub(senderAllowance, _amount))
                }
            }
        }
    }

    function _getData(address _account) internal view returns (bytes32 data) {
        assembly {
            data := sload(_account)
        }
    }

    function _withdrawDirectFromTo(bytes32 _fromData, address _from, address _to, uint _amount) internal {
        assembly {
            if gt(_amount, and(_fromData, BALANCE_MASK)) {
                // `revert InsufficientBalance()`
                mstore(0x00, 0xf4d678b8)
                revert(0x1c, 0x04)
            }
            sstore(_from, sub(_fromData, _amount))
            sstore(TOTAL_SUPPLY_SLOT, sub(sload(TOTAL_SUPPLY_SLOT), _amount))
            mstore(0x00, _amount)
            log3(0x00, 0x20, TRANSFER_EVENT_SIG, _from, 0)

            if iszero(call(gas(), _to, _amount, 0x00, 0x00, 0x00, 0x00)) {
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
        }
    }

    function _computeDomainSeparator() internal view returns (bytes32 domainSeparator) {
        assembly {
            let freeMem := mload(0x40)
            mstore(freeMem, EIP712_DOMAIN_HASH)
            mstore(add(freeMem, 0x20), NAME_HASH)
            mstore(add(freeMem, 0x40), VERSION_HASH)
            mstore(add(freeMem, 0x60), chainid())
            mstore(add(freeMem, 0x80), address())
            domainSeparator := keccak256(freeMem, 0xa0)
        }
    }
}
