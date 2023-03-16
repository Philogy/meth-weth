# METH Security

This document is meant to outline METH's goals, how it works and invariants that are expected to
hold over time to allow for security researchers to more easily dive in and assess the security of
the contract and uncover vulnerabilities.

## System Invariants
- Solvency: `sum(METH balances) <= METH ETH balance (totalSupply)`

## Expected System Properties
- `total ETH in circulation (in wei) < 2^128`

## Known Issues
This section presents a list of non-critical issues, if any of the mentioned issues could be
exploited to steal the funds of others, accounts or have a user lose their own funds while using the
contract correctly according to existing standards may still be elevated.

### Lack of Non-Critical checks
- No minimum calldatasize: The `METH` contract does not enforce a minimum calldatasize meaning calldata
  is implicitly padded with zeros at the end. Incorrect use may therefore lead to a loss if the
  caller e.g. calls the `transfer`, `transferFrom`, `withdrawFrom`, `withdrawFromTo` with an address
  that's only left padded but does not ensure it's right padded, directly concatenating the other
  parameters, leading the amount for the calls to be effectively left shifted.
- No recipient sanity checks: The `METH` contract does not check whether the recipient is the
  contract itself or the zero address, there's a 
- No address dirty bit checks: It is not checked whether the upper bits of an address are dirty, for
  code sections where that may be relevant (address used to determine storage slot, event params)
  the address is masked to clear those bits but the contract will not revert if the upper bits are
  dirty, unlike Solidity.

### Non-critical slot collision
The storage slot used to store the nonce and ERC20 balance of an account is their 20-byte address
(zero-padded). Storage slots to store allowances are determined by hashing together the owner and
spender addresses (`keccak256(abi.encode(owner, spender))`). This means that an allowance slot can
be a valid balance slot if it has 12 leading zero bytes, only requiring you to bruteforce 96-bits
rather than typical 128-bits required for a normal storage layout slot collision (256/2 because of
birthday attack).

Finding such a collision would allow a user to arbitrarily set the balance (and permit nonce) of a
non-existent account by calling `approve(magic_address, desired_balance)`. This would be a _soft_
violation of the solvency invariant as the sum of balances would no longer equal be below or equal
to the contract's reported `totalSupply`. This is only a "soft" break because any balance would be
unspendable without the ability to either determine the private key or deploy a contract at the
desired address. Such a collision would also the attacker to irreverisbly burn METH tokens by
sending them to the found address and using `approve` to set the balance to `0`.

Finding a useable collision would require (by my understanding) similar effort (128-bits) as
collisions for other contracts, because you'd need an accessible allowance slot to collide (256-bits)
with a known address, zero-padded (also 256-bits), which can be 

## Potential Issues To Investigate
- Useable slot collision feasbility
