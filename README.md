# YAM-WETH
"YAM-WETH" is an overall better version of the commonly used [WETH9](https://etherscan.io/token/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2) contract,
providing a trustless, immutable and standardized way for smart contracts to abstract away the
difference between the native ETH asset and fungible [ERC20](https://eips.ethereum.org/EIPS/eip-20) tokens.

> The name "YAM-WETH" is inspired by the name of the YAML format. "YAM-WETH" stands for "Yet Another
> Maximized WETH"

## ✅ Why YAM WETH over WETH9?

### 🔒 More Safety

WETH9 does not have a `permit` method but implements a silent fallback method meaning it'll silently accept
a call to all methods, even ones it hasn't implemented. This often leads to unforseen
vulnerabilities when developers expect their contracts to interact with ERC20 tokens that implement
certain methods or at the very least to revert if they do not implement the methods. This was e.g. the
cause of [Multicoin's $ 1M bridge hack](https://medium.com/zengo/without-permit-multichains-exploit-explained-8417e8c1639b).

YAM-WETH does **not** have a silent fallback method and will revert if it's called for a method it
hasn't implemented. YAM-WETH does however implement its `receive` method. Allowing you to deposit if
you explicitly send ETH along with no calldata.

### 🧩 Backwards Compatible

The previously existing `withdraw`, `deposit` and `receive` fallback method behave like WETH9's
method meaning it should be a drop-in replacement.

The only differences that may have to be considered:
1. Calling `permit` on YAM-WETH will not silently pass, YAM-WETH (currently) implements a permit
   method.
2. Calling methods that are not implemented will not silently pass, if you need to wrap ETH to WETH
   either send it directly with no calldata or use one of the `deposit` methods.

### 👤 Improved UX

**Multicall**

Unlike WETH9, YAM-WETH allows call-batching via its `multicall(bytes[] memory calls)` method. This
allows EOAs to trigger multiple methods in one transaction. This could be used to revoke multiple
allowances in a single transaction or combine different calls together.

**ERC-2612 Permits**

> Note: It's still unsure whether this will make it into the final version due to long-term concerns
> around ec-recover's lack of quantum resistance.

YAM-WETH implements ERC-2612 allowing users to gas-lessly approve contracts and/or interact with
applications that support the standard in a single on-chain transaction rather than two.

**Primary operator**

Primary operators are similar to "approved for all" operators from the ERC721 standard. They have
the permission to spend an infinite amount of tokens on behalf of a user similar to if they were
approved via `weth.approve(operator, type(uint).max);`. A user sets their primary operator via
`setPrimaryOperator(address)` and checks which operator is set via the `primaryOperatorOf(address)`
method. The advantage for user of approving a contract via the primary operator vs. ERC20 allowances
is that the primary operator is stored in the same slot as the balance meaning that setting and
subsequent transfers by the primary operator will cost less gas than ERC20 allowances.

### 💻 Improved Contract-level Interaction
Common patterns are made more efficient by packing them into single calls. Beyond saving on call
overhead the methods are also more efficient because they don't need to update intermediary storage
variables. Certain methods also allow contracts to avoid otherwise unused `receive` / payable `fallback` methods.

- `YAM_WETH.depositTo{ value: amount }(recipient);` replaces:
  ```solidity
  WETH9.deposit{ value: amount}();
  WETH9.transfer(recipient, amount);
  ```
- `YAM_WETH.withdrawTo(recipient, amount);` replaces:
  ```solidity
  receive() external payable {
      require(msg.sender == address(WETH));
  }
  // ...
  WETH9.withdraw(amount);
  SafeTransferLib.safeTransferETH(recipient, amount);
  ```
- `YAM_WETH.withdrawFrom(account, amount);` replaces:
  ```solidity
  WETH9.transferFrom(account, address(this), amount);
  WETH9.withdraw(amount);
  ```
- `YAM_WETH.withdrawFromTo(from, to, amount);` replaces:
  ```solidity
  receive() external payable {
      require(msg.sender == address(WETH));
  }
  // ...
  WETH9.transferFrom(from, address(this), amount);
  WETH9.withdraw(amount);
  SafeTransferLib.safeTransferETH(to, amount);
  ```
- `YAM_WETH.depositToMany(recipients, amount)` replaces:
  ```solidity
  WETH9.deposit{ value: amount * recipients.length }();
  for (uint i = 0; i < recipients.length; i++) {
    WETH9.transfer(recipients[i], amount);
  }

  ```

### ⚡ Highly Optimized
YAM-WETH is written almost entirely in inline-assembly ensuring it's implementation is as efficient
as possible. Certain "require"s are done using the branchless trick demonstrated by [Vectorized](https://twitter.com/optimizoor/status/1611614269900001280).
The branchless requires consume all gas when reverting so they're only used for conditions that can
be verified before submitting a call / transaction such as zero-address and signature validity
checks.

## ⚙️ YAM-WETH under the hood

### Storage Layout
To save gas a non-standard storage layout is used:

Slot Name | Slot Determination | Values Stored (Bits)
----|----|----
Total Supply | `slot = 0` | (95-0: `totalSupply`)
Main Account Data of `account` | `slot = account` | (255-96: `primaryOperator`, 95-0: `balance`)
Allowance `spender` for `owner` | `slot = keccak256(abi.encode(owner, spender))` | (255-0: `allowance`)
ERC-2612 Permit Nonce of `account` | `slot = account << 96` | (255-0: `nonce`)

### Invariants
Environment (Env) or external (Ext) dependency based invariants are assumed facts that if broken would allow for
some failures in the contract. Internal (Int) invariants are invariants that are expected to hold
for the logic, violations are unintended bugs and potential vulnerabilities.

- (Env): `msg.sender` (`caller()`) cannot be the zero-address
- (Int): total supply must never exceed `2**96-1`
- (Int): `balanceOf`, `primaryOperatorOf`, `nonces` will always return `0` for the zero-address
