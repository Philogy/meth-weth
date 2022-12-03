// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {YAM_WETH} from "../src/YetAnotherMaximizedWETH.sol";
import {LibString} from "solady/utils/LibString.sol";

contract YAM_WETH_Test is Test {
    using LibString for address;
    using LibString for uint;

    uint internal constant MAX_PRIV_KEY =
        115792089237316195423570985008687907852837564279074904382605163141518161494336;
    YAM_WETH weth;

    address permit2 = vm.addr(0x929829);

    event Transfer(address indexed from, address indexed to, uint amount);
    event Approval(address indexed owner, address indexed spender, uint amount);
    event PrimaryOperatorSet(address indexed account, address indexed prevOperator, address indexed newOperator);

    modifier realAddr(address _addr) {
        vm.assume(_addr != address(0));
        vm.assume(_addr != address(weth));
        vm.assume(_addr != permit2);
        _;
    }

    modifier not0(address _addr) {
        vm.assume(_addr != address(0));
        _;
    }

    modifier notEq(address _a, address _b) {
        vm.assume(_a != _b);
        _;
    }

    modifier acceptsETH(address _recipient) {
        if (_recipient != address(weth)) {
            (bool success, ) = _recipient.call{value: 1 wei}("");
            vm.assume(success);
        }
        _;
    }

    modifier realPrivKey(uint _privKey) {
        vm.assume(_privKey != 0 && _privKey <= MAX_PRIV_KEY);
        _;
    }

    function setUp() public {
        vm.chainId(1);
        weth = new YAM_WETH(permit2);
    }

    function testName() public {
        assertEq(weth.name(), "Yet Another Maximized Wrapped Ether Contract");
    }

    function testSymbol() public {
        assertEq(weth.symbol(), "WETH");
    }

    function testVersion() public {
        assertEq(weth.version(), "1");
    }

    function testDefaultBalance(address _account) public realAddr(_account) {
        assertEq(weth.balanceOf(_account), 0);
    }

    function testDefaultAllowance(address _owner, address _spender) public realAddr(_owner) {
        assertEq(weth.allowance(_owner, _spender), 0);
    }

    function testDeposit(address _account, uint96 _amount) public realAddr(_account) {
        vm.deal(_account, _amount);
        vm.prank(_account);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), _account, _amount);
        assertTrue(weth.deposit{value: _amount}());
        assertEq(weth.balanceOf(_account), _amount);
        assertEq(weth.totalSupply(), _amount);
    }

    function testDepositFallback(address _account, uint96 _amount) public realAddr(_account) {
        vm.deal(_account, _amount);
        vm.prank(_account);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), _account, _amount);
        (bool success, bytes memory returnData) = address(weth).call{value: _amount}("");
        assertSucceeded(success, returnData);
        assertEq(weth.balanceOf(_account), _amount);
        assertEq(weth.totalSupply(), _amount);
    }

    function testDepositTo(address _from, address _to, uint96 _amount) public realAddr(_from) not0(_to) {
        vm.deal(_from, _amount);
        vm.prank(_from);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), _to, _amount);
        assertTrue(weth.depositTo{value: _amount}(_to));
        assertEq(weth.balanceOf(_to), _amount);
        if (_from != _to) assertEq(weth.balanceOf(_from), 0);
        assertEq(weth.totalSupply(), _amount);
    }

    function testCannotDepositToZero(address _from, uint96 _amount) public realAddr(_from) {
        vm.deal(_from, _amount);
        vm.prank(_from);
        vm.expectRevert(YAM_WETH.ZeroAddress.selector);
        weth.depositTo{value: _amount}(address(0));
    }

    function testDepositAmount(address _account, uint96 _value, uint96 _depositAmount) public realAddr(_account) {
        vm.assume(_value >= _depositAmount);
        vm.deal(_account, _value);
        vm.prank(_account);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), _account, _depositAmount);
        assertTrue(weth.depositAmount{value: _value}(_depositAmount));
        assertEq(weth.balanceOf(_account), _depositAmount);
        assertEq(address(weth).balance, _value);
        assertEq(weth.totalSupply(), _depositAmount);
    }

    function testDepositAmountTo(
        address _from,
        address _to,
        uint96 _value,
        uint96 _depositAmount
    ) public realAddr(_from) not0(_to) {
        vm.assume(_value >= _depositAmount);
        vm.deal(_from, _value);
        vm.prank(_from);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), _to, _depositAmount);
        assertTrue(weth.depositAmountTo{value: _value}(_to, _depositAmount));
        assertEq(weth.balanceOf(_to), _depositAmount);
        if (_from != _to) assertEq(weth.balanceOf(_from), 0);
        assertEq(address(weth).balance, _value);
        assertEq(weth.totalSupply(), _depositAmount);
    }

    function testDepositAmountsTo() public {
        address user1 = vm.addr(1001);
        address user2 = vm.addr(2002);

        uint96 baseBalance1 = 1e18;
        setupBalance(user1, baseBalance1);
        uint96 baseBalance2 = 2.1e18;
        setupBalance(user2, baseBalance2);

        uint amount1 = 390e18;
        uint amount2 = 0.0238e18;
        YAM_WETH.Deposit[] memory deposits = new YAM_WETH.Deposit[](2);
        deposits[0] = YAM_WETH.Deposit(user1, amount1);
        deposits[1] = YAM_WETH.Deposit(user2, amount2);

        address executor = vm.addr(1);

        vm.deal(executor, amount1 + amount2);
        vm.prank(executor);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user2, amount2);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user1, amount1);
        assertTrue(weth.depositAmountsToMany{value: amount1 + amount2}(deposits));
        assertEq(weth.balanceOf(user1), baseBalance1 + amount1);
        assertEq(weth.balanceOf(user2), baseBalance2 + amount2);
    }

    function testWithdraw(
        address _account,
        uint96 _initialWethBalance,
        uint96 _withdrawAmount
    ) public realAddr(_account) acceptsETH(_account) {
        vm.assume(_initialWethBalance >= _withdrawAmount);
        setupBalance(_account, _initialWethBalance);
        uint balBefore = _account.balance;
        vm.prank(_account);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_account, address(0), _withdrawAmount);
        assertTrue(weth.withdraw(_withdrawAmount));
        assertEq(weth.balanceOf(_account), _initialWethBalance - _withdrawAmount);
        assertEq(_account.balance, balBefore + _withdrawAmount);
    }

    function testWithdrawTo(
        address _from,
        address _to,
        uint96 _initialWethBalance,
        uint96 _withdrawAmount
    ) public not0(_from) realAddr(_to) acceptsETH(_to) {
        vm.assume(_initialWethBalance >= _withdrawAmount);
        setupBalance(_from, _initialWethBalance);

        uint wethBalBefore = address(weth).balance;
        uint toBalBefore = _to.balance;

        vm.prank(_from);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_from, address(0), _withdrawAmount);
        assertTrue(weth.withdrawTo(_to, _withdrawAmount));

        assertEq(weth.balanceOf(_from), _initialWethBalance - _withdrawAmount);
        assertEq(_to.balance, toBalBefore + _withdrawAmount);
        assertEq(address(weth).balance, wethBalBefore - _withdrawAmount);
    }

    function testCannotWithdrawInsufficientBalance(
        address _account,
        uint96 _initialWethBalance,
        uint96 _withdrawAmount
    ) public realAddr(_account) {
        vm.assume(_initialWethBalance < _withdrawAmount);
        setupBalance(_account, _initialWethBalance);
        vm.prank(_account);
        vm.expectRevert(YAM_WETH.InsufficientBalance.selector);
        weth.withdraw(_withdrawAmount);
    }

    function testSetOperator(
        address _account,
        address _operator1,
        address _operator2,
        uint96 _initialBalance
    ) public realAddr(_account) {
        setupBalance(_account, _initialBalance);

        vm.prank(_account);
        vm.expectEmit(true, true, true, true);
        emit PrimaryOperatorSet(_account, address(0), _operator1);
        weth.setPrimaryOperator(_operator1);
        assertEq(weth.balanceOf(_account), _initialBalance);
        assertEq(weth.primaryOperatorOf(_account), _operator1);

        vm.prank(_account);
        vm.expectEmit(true, true, true, true);
        emit PrimaryOperatorSet(_account, _operator1, _operator2);
        assertTrue(weth.setPrimaryOperator(_operator2));
        assertEq(weth.balanceOf(_account), _initialBalance);
        assertEq(weth.primaryOperatorOf(_account), _operator2);
    }

    function testSupplyCap96(address _account, uint _amount) public realAddr(_account) {
        vm.assume(_amount > uint(type(uint96).max));
        vm.deal(_account, _amount);
        vm.prank(_account);
        vm.expectRevert(YAM_WETH.TotalSupplyOverflow.selector);
        weth.deposit{value: _amount}();
    }

    function testTransfer(
        address _from,
        address _to,
        uint96 _fromStartBal,
        uint96 _toStartBal,
        uint96 _transferAmount
    ) public realAddr(_from) not0(_to) {
        vm.assume(_transferAmount <= _fromStartBal);
        vm.assume(uint(_fromStartBal) + uint(_toStartBal) <= type(uint96).max);
        setupBalance(_from, _fromStartBal);
        setupBalance(_to, _toStartBal);

        vm.prank(_from);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_from, _to, _transferAmount);
        assertTrue(weth.transfer(_to, _transferAmount));
        if (_from != _to) {
            assertEq(weth.balanceOf(_from), _fromStartBal - _transferAmount, "from bal mismatch");
            assertEq(weth.balanceOf(_to), _toStartBal + _transferAmount, "to bal mismatch");
        }
    }

    function testCannotTransferToZero(address _from, uint96 _amount) public realAddr(_from) {
        setupBalance(_from, _amount);
        vm.prank(_from);
        vm.expectRevert(YAM_WETH.ZeroAddress.selector);
        weth.transfer(address(0), _amount);
    }

    function testCannotTransferFromToZero(
        address _operator,
        address _from,
        uint96 _amount
    ) public realAddr(_operator) realAddr(_from) {
        setupBalance(_from, _amount);
        setupOperator(_from, _operator);

        vm.prank(_operator);
        vm.expectRevert(YAM_WETH.ZeroAddress.selector);
        weth.transferFrom(_from, address(0), _amount);
    }

    function testCannotTransferFromZero(
        address _operator,
        address _to,
        uint96 _amount
    ) public realAddr(_operator) not0(_to) {
        // ensure supply
        setupBalance(vm.addr(1), 100e18);

        vm.prank(_operator);
        vm.expectRevert(YAM_WETH.ZeroAddress.selector);
        weth.transferFrom(address(0), _to, _amount);
    }

    function testTransferFromAsOperator(
        address _operator,
        address _from,
        address _to,
        uint96 _transferAmount
    ) public realAddr(_operator) realAddr(_from) not0(_to) {
        setupOperator(_from, _operator);
        setupBalance(_from, _transferAmount);

        vm.prank(_operator);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_from, _to, _transferAmount);
        assertTrue(weth.transferFrom(_from, _to, _transferAmount));
        if (_from != _to) assertEq(weth.balanceOf(_from), 0, "from bal mismatch");
        assertEq(weth.balanceOf(_to), _transferAmount, "to bal mismatch");
        assertEq(weth.primaryOperatorOf(_from), _operator);
    }

    function testTransferFromInfiniteApproval(
        address _operator,
        address _from,
        address _to,
        uint96 _transferAmount
    ) public realAddr(_operator) realAddr(_from) not0(_to) notEq(_from, _to) {
        setupBalance(_from, _transferAmount);

        setupAllowance(_from, _operator, type(uint).max);

        vm.prank(_operator);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_from, _to, _transferAmount);
        assertTrue(weth.transferFrom(_from, _to, _transferAmount));
        assertEq(weth.balanceOf(_from), 0);
        assertEq(weth.balanceOf(_to), _transferAmount);
        assertEq(weth.allowance(_from, _operator), type(uint).max);
    }

    function testTransferFromLimitedApproval(
        address _operator,
        address _from,
        address _to,
        uint96 _transferAmount,
        uint _allowance
    ) public realAddr(_operator) realAddr(_from) not0(_to) {
        vm.assume(_allowance >= _transferAmount);
        vm.assume(_allowance != type(uint).max);
        setupBalance(_from, _transferAmount);

        setupAllowance(_from, _operator, _allowance);

        vm.prank(_operator);
        vm.expectEmit(true, true, true, true);
        emit Transfer(_from, _to, _transferAmount);
        assertTrue(weth.transferFrom(_from, _to, _transferAmount));
        assertEq(weth.balanceOf(_to), _transferAmount);
        if (_from != _to) assertEq(weth.balanceOf(_from), 0);
        assertEq(weth.allowance(_from, _operator), _allowance - _transferAmount);
    }

    function testCannotTransferInsufficientBalance(
        address _from,
        address _to,
        uint96 _fromStartBal,
        uint96 _transferAmount
    ) public realAddr(_from) not0(_to) {
        vm.assume(_fromStartBal < _transferAmount);
        setupBalance(_from, _fromStartBal);
        vm.prank(_from);
        vm.expectRevert(YAM_WETH.InsufficientBalance.selector);
        weth.transfer(_to, _transferAmount);
    }

    function testCannotTransferFromNoApproval(address _operator, address _from) public realAddr(_operator) not0(_from) {
        setupBalance(_from, 1e18);

        vm.prank(_operator);
        vm.expectRevert(YAM_WETH.InsufficientPermission.selector);
        weth.transferFrom(_from, _operator, 1);
    }

    function testCannotTransferZeroFromZero(address _operator) public realAddr(_operator) {
        vm.prank(_operator);
        vm.expectRevert(YAM_WETH.ZeroAddress.selector);
        weth.transferFrom(address(0), _operator, 0);
    }

    function testCannotTransferFromInsufficientApproval(
        address _operator,
        address _from,
        uint96 _startBal,
        uint _allowance
    ) public realAddr(_operator) not0(_from) {
        vm.assume(_allowance < _startBal);
        setupBalance(_from, _startBal);

        setupAllowance(_from, _operator, _allowance);

        vm.prank(_operator);
        vm.expectRevert(YAM_WETH.InsufficientPermission.selector);
        weth.transferFrom(_from, _operator, _startBal);
    }

    function testApprove(address _owner, address _spender, uint _allowance) public realAddr(_owner) {
        vm.prank(_owner);
        vm.expectEmit(true, true, true, true);
        emit Approval(_owner, _spender, _allowance);
        assertTrue(weth.approve(_spender, _allowance));
        assertEq(weth.allowance(_owner, _spender), _allowance);
    }

    function testPreventsDirtyApprove(address _owner, uint _dirtySpender, uint _allowance) public realAddr(_owner) {
        vm.assume(_dirtySpender > type(uint160).max);
        vm.prank(_owner);
        vm.expectRevert(bytes(""));
        (bool success, ) = address(weth).call(
            abi.encodeWithSelector(YAM_WETH.approve.selector, _dirtySpender, _allowance)
        );
        assertTrue(success);
    }

    function testPreventsDirtyAllowance(uint _dirtyOwner, uint _dirtySpender) public {
        vm.assume(_dirtyOwner > type(uint160).max || _dirtySpender > type(uint160).max);

        vm.expectRevert(bytes(""));
        (bool success, ) = address(weth).staticcall(
            abi.encodeWithSelector(YAM_WETH.allowance.selector, _dirtyOwner, _dirtySpender)
        );
        assertTrue(success);
    }

    function testPreventsDirtyTransferFrom(
        address _operator,
        uint _dirtyFrom,
        address _to
    ) public realAddr(_operator) not0(_to) {
        vm.assume(_dirtyFrom > type(uint160).max);
        vm.prank(_operator);
        vm.expectRevert(bytes(""));
        (bool success, ) = address(weth).call(
            abi.encodeWithSelector(YAM_WETH.transferFrom.selector, _dirtyFrom, _to, 0)
        );
        assertTrue(success);
    }

    function testDomainSeparator() public {
        assertEq(
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(weth.name())),
                    keccak256(bytes(weth.version())),
                    block.chainid,
                    address(weth)
                )
            ),
            weth.DOMAIN_SEPARATOR()
        );

        string[] memory eip712cmd = new string[](5);
        eip712cmd[0] = "node";
        eip712cmd[1] = "script/eip712.js";
        eip712cmd[2] = "domain-separator";
        eip712cmd[3] = address(weth).toHexStringChecksumed();
        eip712cmd[4] = weth.name();
        bytes32 actualDomainSeparator = bytes32(vm.ffi(eip712cmd));
        assertEq(actualDomainSeparator, weth.DOMAIN_SEPARATOR(), "actual domain separator");
    }

    function testGetNonce(address _account, uint _nonce) external not0(_account) {
        setupNonce(_account, _nonce);
        assertEq(weth.nonces(_account), _nonce);
    }

    function testValidPermit(
        uint _ownerPrivkey,
        address _spender,
        uint _allowance,
        uint _nonce
    ) public realPrivKey(_ownerPrivkey) {
        vm.assume(_nonce != type(uint).max);

        address owner = vm.addr(_ownerPrivkey);
        setupNonce(owner, _nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _ownerPrivkey,
            computePermitHash(owner, _spender, _allowance, _nonce, block.timestamp)
        );

        vm.expectEmit(true, true, true, true);
        emit Approval(owner, _spender, _allowance);
        weth.permit(owner, _spender, _allowance, block.timestamp, v, r, s);
        assertEq(weth.nonces(owner), _nonce + 1);
        assertEq(weth.allowance(owner, _spender), _allowance);
    }

    function testCannotSubmitExpiredPermit(
        uint _ownerPrivkey,
        address _spender,
        uint _allowance,
        uint _nonce,
        uint _deadline
    ) public realPrivKey(_ownerPrivkey) {
        vm.assume(_nonce != type(uint).max);
        vm.assume(block.timestamp > _deadline);

        address owner = vm.addr(_ownerPrivkey);
        setupNonce(owner, _nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _ownerPrivkey,
            computePermitHash(owner, _spender, _allowance, _nonce, _deadline)
        );

        vm.expectRevert(YAM_WETH.PermitExpired.selector);
        weth.permit(owner, _spender, _allowance, _deadline, v, r, s);
    }

    function testCannotSubmitInvalidSignaturePermit(
        address _owner,
        address _spender,
        uint _allowance,
        uint _nonce,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public realAddr(_owner) realAddr(_spender) {
        vm.assume(
            ecrecover(computePermitHash(_owner, _spender, _allowance, _nonce, block.timestamp), _v, _r, _s) ==
                address(0)
        );
        vm.expectRevert(YAM_WETH.InvalidSignature.selector);
        weth.permit(_owner, _spender, _allowance, block.timestamp, _v, _r, _s);
    }

    function testCannotSubmitImpersonatedPermit(
        uint _fakePrivKey,
        address _owner,
        address _spender,
        uint _allowance,
        uint _nonce
    ) public realPrivKey(_fakePrivKey) {
        vm.assume(vm.addr(_fakePrivKey) != _owner);
        setupNonce(_owner, _nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _fakePrivKey,
            computePermitHash(_owner, _spender, _allowance, _nonce, block.timestamp)
        );
        vm.expectRevert(YAM_WETH.InvalidSignature.selector);
        weth.permit(_owner, _spender, _allowance, block.timestamp, v, r, s);
    }

    function testCannotSubmitInvalidNoncePermit(
        uint _ownerPrivkey,
        address _spender,
        uint _allowance,
        uint _nonce
    ) public realPrivKey(_ownerPrivkey) {
        vm.assume(_nonce != type(uint).max);

        address owner = vm.addr(_ownerPrivkey);
        setupNonce(owner, _nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _ownerPrivkey,
            computePermitHash(owner, _spender, _allowance, _nonce + 1, block.timestamp)
        );

        vm.expectRevert(YAM_WETH.InvalidSignature.selector);
        weth.permit(owner, _spender, _allowance, block.timestamp, v, r, s);
    }

    function testPermitHashScript(
        address _owner,
        address _spender,
        uint _allowance,
        uint _nonce,
        uint _deadline
    ) public {
        bytes32 eip712Payload = computePermitHash(_owner, _spender, _allowance, _nonce, _deadline);
        bytes32 actualPayload = getPermitHash(_owner, _spender, _allowance, _nonce, _deadline);

        assertEq(actualPayload, eip712Payload);
    }

    function setupBalance(address _account, uint96 _balance) internal {
        vm.deal(_account, _balance);
        vm.prank(_account);
        weth.deposit{value: _balance}();
    }

    function setupOperator(address _account, address _operator) internal {
        vm.prank(_account);
        weth.setPrimaryOperator(_operator);
    }

    function setupNonce(address _account, uint _nonce) internal {
        vm.store(address(weth), bytes32(uint(uint160(_account)) << 96), bytes32(_nonce));
    }

    function setupAllowance(address _account, address _spender, uint _allowance) internal {
        vm.prank(_account);
        weth.approve(_spender, _allowance);
    }

    function computePermitHash(
        address _owner,
        address _spender,
        uint _allowance,
        uint _nonce,
        uint _deadline
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    weth.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                            ),
                            _owner,
                            _spender,
                            _allowance,
                            _nonce,
                            _deadline
                        )
                    )
                )
            );
    }

    function getPermitHash(
        address _owner,
        address _spender,
        uint _allowance,
        uint _nonce,
        uint _deadline
    ) internal returns (bytes32) {
        string[] memory eip712cmd = new string[](10);
        eip712cmd[0] = "node";
        eip712cmd[1] = "script/eip712.js";
        eip712cmd[2] = "permit";
        eip712cmd[3] = address(weth).toHexStringChecksumed();
        eip712cmd[4] = weth.name();
        eip712cmd[5] = _owner.toHexStringChecksumed();
        eip712cmd[6] = _spender.toHexStringChecksumed();
        eip712cmd[7] = _allowance.toString();
        eip712cmd[8] = _nonce.toString();
        eip712cmd[9] = _deadline.toString();
        return bytes32(vm.ffi(eip712cmd));
    }

    function assertSucceeded(bool _success, bytes memory _returndata) internal {
        assertTrue(_success);
        bool returnedFlag = abi.decode(_returndata, (bool));
        assertTrue(returnedFlag);
    }
}
