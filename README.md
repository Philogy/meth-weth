# METH

> A Wrapped Ether implementation so efficient it'll make your teeth fall out

"METH" is an overall better version of the commonly used [WETH9](https://etherscan.io/token/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2) contract,
providing a trustless, immutable and standardized way for smart contracts to abstract away the
difference between the native ETH asset and fungible [ERC20](https://eips.ethereum.org/EIPS/eip-20) tokens.

## 🪨 Deploy Instances

(pending final implementation and audits)

## 🏆 Gas Use: METH vs WETH9

(pending final implementation)

## ✅ Why METH over WETH9?

### 🔒 More Safety

WETH9 does not have a `permit` method but implements a silent fallback method meaning it'll silently accept
a call to all methods, even ones it hasn't implemented. This often leads to unforseen
vulnerabilities when developers expect their contracts to interact with ERC20 tokens that implement
certain methods or at the very least to revert if they do not implement the methods. This was e.g. the
cause of [Multicoin's $ 1M bridge hack](https://medium.com/zengo/without-permit-multichains-exploit-explained-8417e8c1639b).

_METH_ does **not** have a silent fallback method and will revert if it's called for a method it
hasn't implemented. _METH_ does however implement a payable `receive` fallback method. Allowing you to deposit
if you explicitly send ETH along with no calldata.

### 🧩 Backwards Compatible

The previously existing `withdraw`, `deposit` and `receive` fallback method behave like WETH9's
method meaning it should be a drop-in replacement.

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
  uint amount = WETH9.balanceOf(address(this));
  WETH9.withdraw();
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
Main Account Data of `account` | `slot = account` | (255-128: `nonce`, 127-0: `balance`)
Allowance `spender` for `owner` | `slot = keccak256(abi.encode(owner, spender))` | (255-0: `allowance`)

