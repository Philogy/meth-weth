# METH

> A Wrapped Ether implementation so efficient it'll make your teeth fall out 🦷

"METH" is an overall better version of the commonly used [WETH9](https://etherscan.io/token/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2) contract,
providing a trustless, immutable and standardized way for smart contracts to abstract away the
difference between the native ETH asset and fungible [ERC20](https://eips.ethereum.org/EIPS/eip-20) tokens.

## 🪨 Deployed Instances

(pending final implementation and audits)

## 🏆 Gas Use: METH vs WETH9

**STILL A WORK IN PROGRESS, MORE COMPARISONS PENDING**

Comparison may improve in favor of _METH_ if more optimizations are found.


### Direct Calls
This table contains a comparison of gas costs for limited function calls.

|Action|WETH9|METH|Difference|Added Details|
|------|-----|----|----------|-------------|
|`deposit()`|45,038|44,501|-537|Wrap non-zero amount with no existing balance|
|`transfer(...)`|51,534|50,560|-974|Transfer to account with zero balance|
|receive-fallback|27,631|27,333|-298|Wrap non-zero amount with existing balance|
|`approve(...)`|46,364|45,465|-899|Grant infinite allowance (requires truncating calldata for METH)|
|`withdraw(...)`|35,144|34,395|-749|Unwrap specific amount|
|`transferFrom(...)`|36,965|36,033|-932|Transfer from non-zero to non-zero with infinite approval|
|`transferFrom(...)`|35,688|34,158|-1,530|Transfer from non-zero to non-zero with finite approval|
|withdraw all remaining balance|30,344|29,430|-914|Unwrap all remaining (`withdraw(uint)` in WETH, `withdrawAll()` in METH)|


## ✅ Why METH over WETH9?

### 🔒 Fewer Footguns

WETH9 does not have a `permit` method but implements a silent fallback method meaning it'll silently accept
a call to all methods, even ones it hasn't implemented. This often leads to unforseen
vulnerabilities when developers expect their contracts to interact with ERC20 tokens that implement
certain methods or at the very least to revert if they do not implement the methods. This was e.g. the
cause of [Multicoin's $ 1M bridge hack](https://medium.com/zengo/without-permit-multichains-exploit-explained-8417e8c1639b).

_METH_ does **not** have a silent fallback method and will revert if it's called for a method it
hasn't implemented. _METH_ does however implement a payable `receive` fallback method. Allowing you to wrap ETH
if you explicitly send ETH to the contract along with no calldata.

### 🧩 Backwards Compatible

The previously existing `withdraw`, `deposit` and `receive` fallback method behave like WETH9's
methods meaning it's a drop-in replacement.

The only difference that may have to be considered:
Calling methods that are not implemented will not silently pass, if you need to wrap ETH to WETH
either send it directly with no calldata or use one of the `deposit` methods. Calling an
unimplemented function _may_ consume all gas sent to the contract.

Following (unimplemented) selectors will lead to an exceptional revert, consuming all gas when
called:
```
0x0a000000 - 0x0affffff 
0x21000000 - 0x21ffffff 
0x24000000 - 0x24ffffff 
0x29000000 - 0x29ffffff 
0x2f000000 - 0x2fffffff 
0x4b000000 - 0x4bffffff 
0x86000000 - 0x86ffffff 
0xaa000000 - 0xaaffffff 
0xae000000 - 0xaeffffff 
0xcb000000 - 0xcbffffff 
```

### 👤 Improved UX



### 💻 Improved Contract-level Interaction

Common patterns are made more efficient by packing them into single calls. Beyond saving on call
overhead the methods are also more efficient because they don't need to update intermediary storage
variables. Certain methods also allow contracts to avoid otherwise unused `receive` / payable `fallback` methods.

- `METH.depositTo{ value: amount }(recipient);` replaces:
  ```solidity
  WETH9.deposit{ value: amount}();
  WETH9.transfer(recipient, amount);
  ```
- `METH.depositAndApprove{ value: amount }(spender, amount);` replaces:
  ```solidity
  WETH9.deposit{ value: amount}();
  WETH9.approve(spender, amount);
  ```
- `METH.withdrawTo(recipient, amount);` replaces:
  ```solidity
  receive() external payable {
      require(msg.sender == address(WETH));
  }
  // ...
  WETH9.withdraw(amount);
  SafeTransferLib.safeTransferETH(recipient, amount);
  ```
- `METH.withdrawFrom(account, amount);` replaces:
  ```solidity
  WETH9.transferFrom(account, address(this), amount);
  WETH9.withdraw(amount);
  ```
- `METH.withdrawFromTo(from, recipient, amount);` replaces:
  ```solidity
  receive() external payable {
      require(msg.sender == address(WETH));
  }
  // ...
  WETH9.transferFrom(from, address(this), amount);
  WETH9.withdraw(amount);
  SafeTransferLib.safeTransferETH(recipient, amount);
  ```
- `METH.withdrawAll();` replaces:
  ```solidity
  WETH9.withdraw(WETH9.balanceOf(address(this)));
  ```
- `METH.withdrawAllTo(recipient);` replaces:
  ```solidity
  receive() external payable {
      require(msg.sender == address(WETH));
  }
  // ...
  uint amount = WETH9.balanceOf(address(this));
  WETH9.withdraw(amount);
  SafeTransferLib.safeTransferETH(recipient, amount);
  ```

### ⚡ Highly Optimized
_METH_ is written directly in bytecode-level assembly using the [Huff](https://huff.sh) language, ensuring its implementation is as efficient
as possible.

## ⚙️ "METH" under the hood

### Storage Layout
To save gas a non-standard storage layout is used:

Slot Name | Slot Determination | Values Stored (Bits)
----|----|----
Main Data of `account` | `slot = account_address` | (255-128: `nonce`, 127-0: `balance`)
Allowance from `spender` for `owner` | `slot = keccak256(abi.encode(owner, spender))` | (255-0: `allowance`)

The layout ensures minimal overhead when storing balances. The layout however also makes it possible
for an allowance and balance slot to collide. Making it possible for someone to destroy WETH or mint
unsusable WETH by finding an allowance slot with 12 leading zero bytes (96-bit bruteforce). For more
details on the implications of this view the [Security doc](./SECURITY.md).

### Function Dispatcher
METH uses a constant gas function dispatcher that jumps to any function in its ABI in only 34-gas:

Step gas cost|Cumulative gas cost|Op-Code |Stack|Explanation
-------------|---------------|------------------|-----|----------------
2|2|PUSH0|[`0`]|Push 0 using 2 gas ([EIP-3855](https://eips.ethereum.org/EIPS/eip-3855) included in the Shangai upgrade)
3|5|CALLDATALOAD|[`calldata[0:32]`]|Load calldata (including selector)
3|8|PUSH1 0xE0|[`0xe0 (224)`; `calldata[0:32]`]|Push selector offset
3|11|SHR|[`selector`]|Bitshift right to get 4 upper most bytes of calldata i.e. selector
3|14|DUP1|[`selector`; `selector`]|Duplicate selector on stack for jump table
3|17|PUSH1 0x12|[`0x12 (18)`, `selector`; `selector`]|Push unique selector bits offset
3|20|SHR|[`unique_bits`; `selector`]|Bitshift right to get the 14 uppermost bits of the selector
3|23|PUSH1 0x3F|[`0x3f (0b111111)`; `unique_bits`; `selector`]|Push lower bit mask
3|26|OR|[`jump_destination`; `selector`]|Masks lower bits to ensure there's sufficient space between destinations
8|34|JUMP|[`selector`]|Jump to function.

Each function verifies whether the selector matches its function selector as whole, this is done to
ensure that the contract actually reverts if it's called with a selector where the identifying
8-bits match with an existing function but the full selector does not e.g. (from `name()`):

Step gas cost|Cumulative gas cost|Op-Code |Stack|Explanation
-------------|---------------|------------------|-----|----------------
1|1|JUMPDEST|[`selector`]|"Landing pad" of function from dispatcher
3|4|PUSH4 0x06fdde03|[`name.selector`, `selector`]|Pushes expected selector to stack
3|7|SUB|[`selector_diff`]|Use subtraction operator as inequality check
2|9|CALLVALUE|[`msg.value`, `selector_diff`]|Push `msg.value`
3|12|OR|[`invalid_call`]|Bitwise OR results in non-zero value if either selector didn't match or ETH was sent
3|15|PUSH2 0x40e1|[`revert_dest`, `invalid_call`]|Pushes revert destination to stack
10|25|JUMPI|[]|Jumps to a revert if `invalid_call` is non-zero

Due to the cost of the `JUMPI` opcode some functions that have more conditions defer the actual 
branching instruction until it can bundle together the check of multiple conditions e.g.
`withdraw(uint)` uses only 1 `JUMPI` to check both the selector and that the caller has sufficient
balance.
