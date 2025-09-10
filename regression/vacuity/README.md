# Vacuous Pass

## Specification
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


## Properties
- **correct-pass**: After an assert(true), when the state is reachable, the prover finds no violation.
- **correct-violation**: After an assert(false), when the state is reachable, the prover finds a violation.
- **vacuous-pass**: After an assert(false), when the state is unreachable, the prover finds a violation.
- **vacuous-pass-vacuity-check**: After an assert(false), when the state is unreachable, the prover finds a violation.

## Ground truth

- [Ground truth](ground-truth.csv)
- [Solcmc/z3](solcmc-z3.csv)
- [Solcmc/Eldarica](solcmc-eld.csv)
- [Certora](certora.csv)

## Experiments
### SolCMC
#### Z3
|        | correct-pass               | correct-violation          | vacuous-pass               | vacuous-pass-vacuity-check |
|--------|----------------------------|----------------------------|----------------------------|----------------------------|
| **v1** | ND                         | ND                         | ND                         | ND                         |
 

#### ELD
|        | correct-pass               | correct-violation          | vacuous-pass               | vacuous-pass-vacuity-check |
|--------|----------------------------|----------------------------|----------------------------|----------------------------|
| **v1** | ND                         | ND                         | ND                         | ND                         |
 


### Certora
|        | correct-pass               | correct-violation          | vacuous-pass               | vacuous-pass-vacuity-check |
|--------|----------------------------|----------------------------|----------------------------|----------------------------|
| **v1** | TP!                        | TN                         | FP!                        | ERR                        |
 

