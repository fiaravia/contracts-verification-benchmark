## Vacuity Smart Contract

The **Vacuity** contract is a very simple Solidity contract with the following features:

- It maintains a single public state variable `v`, initialized to `0`.
- It has a function `set(uint256 x)`:
  - The function only succeeds if `x == 1`.
  - If successful, it updates the state variable `v` to `1`.
  - Any other input will cause the transaction to revert with the error `"only 1 allowed"`.

In essence, the contract only allows `v` to ever be set to `1` — no other values are permitted.

---

## Intent of Regression Test

The purpose of this contract is to serve as a **regression test for Certora outputs**.  
Specifically, it is used to check the behavior when a rule is **vacuously true** (i.e., the precondition of the rule can never be satisfied, so the rule holds trivially).
