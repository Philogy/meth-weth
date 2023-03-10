# METH

> A Wrapped Ether implementation so efficient it'll make your teeth fall out

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
|`deposit()`|45,038|44,628|-410|Wrap non-zero amount with no existing balance|
|`transfer(...)`|51,534|50,590|-944|Transfer to account with zero balance|
|receive-fallback|27,631|27,463|-168|Wrap non-zero amount with no existing balance|
|`approve(...)`|46,364|45,485|-879|Grant infinite allowance (requires truncating calldata for METH)|
|`withdraw(...)`|35,144|34,535|-609|Unwrap specific amount|
|`transferFrom(...)`|36,965|36,059|-906|Transfer from non-zero to non-zero with infinite approval|
|`transferFrom(...)`|35,688|34,188|-1,500|Transfer from non-zero to non-zero with finite approval|
|withdraw all remaining balance|30,344|29,570|-774|Unwrap all remaining (`withdraw(uint)` in WETH, `withdrawAll()` in METH)|



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

The only differences that may have to be considered:
1. Calling `permit` on _METH_ will not silently pass, _METH_ implements a permit method according to
   the [ERC-2612](https://eips.ethereum.org/EIPS/eip-2612) standard
2. Calling methods that are not implemented will not silently pass, if you need to wrap ETH to WETH
   either send it directly with no calldata or use one of the `deposit` methods.

### 👤 Improved UX

**Multicall**

Unlike WETH9, _METH_ allows call-batching via its `multicall(bytes[] memory calls)` method. This
allows EOAs to trigger multiple methods in one transaction. This could be used to revoke multiple
allowances in a single transaction or combine different calls together. However sending ETH to the
`multicall` method is disallowed for security reasons meaning `deposit` and `depositTo` cannot be
called as part of a `multicall` transaction.

**ERC-2612 Permits**

_METH_ is a [ERC-2612](https://eips.ethereum.org/EIPS/eip-2612) compliant ERC20 token allowing users to
gas-lessly approve contracts and/or interact with applications that support the standard in a single
on-chain transaction rather than two.

### 💻 Improved Contract-level Interaction

Common patterns are made more efficient by packing them into single calls. Beyond saving on call
overhead the methods are also more efficient because they don't need to update intermediary storage
variables. Certain methods also allow contracts to avoid otherwise unused `receive` / payable `fallback` methods.

- `METH.depositTo{ value: amount }(recipient);` replaces:
  ```solidity
  WETH9.deposit{ value: amount}();
  WETH9.transfer(recipient, amount);
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
_METH_ is written directly in bytecode-level assembly using the [Huff](https://huff.sh) langauge, ensuring it's implementation is as efficient
as possible. Certain "require"s are done using the branchless trick demonstrated by [Vectorized](https://twitter.com/optimizoor/status/1611614269900001280).
The branchless requires consume all gas when reverting so they're only used for conditions that can
be verified before submitting a call / transaction such as zero-address and signature validity
checks.

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
METH uses a constant gas function dispatcher that dispatches any function in its ABI in only 55-gas,
the `receive` fallback function is dispatched in 54 gas. This is done by extracting unique bits from
the selector, interpreting it as a jump destination and then doing a single direct selector
comparison to ensure collisions are excluded.

A breakdown of the function dispatcher is done here:

Step gas cost|Cumulative gas cost|Op-Code |Stack|Explanation
-------------|---------------|------------------|-----|----------------
2|2|PC|[`0`]|Push 0 using 2 instead of 3 gas
3|5|CALLDATALOAD|[`calldata[0:32]`]|Load calldata (including selector)
3|8|PUSH1 0xE0|[`0xe0 (224)`; `calldata[0:32]`]|Push selector offset
3|11|SHR|[`selector`]|Bitshift right to get 4 upper most bytes of calldata i.e. selector
3|14|DUP1|[`selector`; `selector`]|Duplicate selector on stack for jump table
3|17|PUSH1 0x14|[`0x14 (20)`, `selector`; `selector`]|Push unique selector bits offset
3|20|SHR|[`unique_bits`; `selector`]|Bitshift right to get the 12 uppermost bits of the selector
3|23|PUSH1 0x0F|[`0xf (0b1111)`; `unique_bits`; `selector`]|Push lower bit mask
3|26|OR|[`jump_destination`; `selector`]|Masks lower bits to ensure there's sufficient space between destinations
8|34|JUMP|[`selector`]|Jump to selector's check.
1|35|JUMPDEST|[`selector`]|Destination (256 to cover full selector range)
3|38|PUSH4 `<expected_selector>`|[`expected_selector`, `selector`]|Push expected selector for the final comparison
3|41|EQ|[`selector_matches`]|Check selector (necessary to rule out collision between different selector with same top bits)
3|44|PUSH2 `final_dest`|[`final_dest`; `selector_matches`]|Push destination of actual function logic
10|54|JUMPI|[]|Do the final jump if selectors matched. Will continue to a revert if comparison failed
1|55|JUMPDEST|[]|Destination of actual function code

The final check is slightly modified for the destination of the `receive()` fallback function.
Instead of `PUSH4 <expected_selector> EQ` it does `CALLDATASIZE ISZERO` costing one less gas.
Retrieving the selector (`PC CALLDATALOAD PUSh1 0xE0 SHR`) will still work for a call with no calldata as `CALLDATALOAD` reverts to
pushing 0 for out-of-bounds calldata. 

If no selector in the ABI has a certain uppermost byte.
