# Payment Splitter

## Specification
This contract allows to split Ether payments among a group of accounts. The sender does not need to be aware that the Ether will be split in this way, since it is handled transparently by the contract.

The split can be in equal parts or in any other arbitrary proportion. The way this is specified is by assigning each account to a number of shares. Of all the Ether that this contract receives, each account will then be able to claim an amount proportional to the percentage of total shares they were assigned. The distribution of shares is set at the time of contract deployment and can't be updated thereafter.

 `PaymentSplitter` follows a pull payment model. This means that payments are not automatically forwarded to the accounts but kept in this contract, and the actual transfer is triggered as a separate step by calling the release() function.

This implementation of the PaymentSplitter contract includes additional getter functions to support formal verification with tools like Certora. 

These functions expose key pieces of information and perform aggregation calculations, enabling rigorous analysis of contract properties and invariants. The added modifications preserve the original functionality and security of the contract while providing enhanced visibility for verification purposes.

## Properties
- **fair-split**:  for every account `a` in `payees`, `released[a] + releasable(a) == (totalReceived * shares[a]) / totalShares`.
- **fair-split-for-v3**:  for every account `a` in `payees`, `released[a] <= (totalReceived + totalReleased) / 3`.
- **funds-get-transferred**:  for all accounts `a` in `payees`, if `releasable(a) > 0`, then `release(a)` does not revert.
- **non-zero-payees**:  for all accounts `a` in `payees`, `a != address(0)`.
- **positive-shares**:  for all addresses `addr` in `payees`, `shares[addr] > 0`.
- **releasable-balance-check**:  for all addresses `addr` in `payees`, `releasable(addr)` is less than or equal to the balance of the contract.
- **releasable-sum-balance**:  the sum of the releasable funds for every accounts is equal to the balance of the contract.
- **release-release-revert**:  two consecutive calls to `release` for the same account `a`, without there being any transfer to the contract in between calls, should revert on the second call.
- **swappable-call-order**:  making two different calls in any order to 'release' should yield the same state as a result.
- **zero-dust**:  the contract should always be able to release all funds with no leftovers.

## Versions
- **v1**: conformant to specification
- **v2**: conformant to specification
- **v3**: this version has a fixed number of payees (3) and does not accept dynamic shares.

## Ground truth
|        | fair-split               | fair-split-for-v3        | funds-get-transferred     | non-zero-payees          | positive-shares          | releasable-balance-check | releasable-sum-balance   | release-release-revert   | swappable-call-order     | zero-dust                |
|--------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|
| **v1** | 1                        | 0                        | 0                        | 1                        | 1                        | 1                        | 0                        | 1                        | 0                        | 0                        |
| **v2** | 1                        | 0                        | 0                        | 1                        | 1                        | 1                        | 0                        | 1                        | 0                        | 0                        |
| **v3** | 1                        | 1                        | 0                        | 1                        | 1                        | 1                        | 0                        | 1                        | 0                        | 0                        |
 

## Experiments
### SolCMC
#### Z3
|        | fair-split               | fair-split-for-v3        | funds-get-transferred     | non-zero-payees          | positive-shares          | releasable-balance-check | releasable-sum-balance   | release-release-revert   | swappable-call-order     | zero-dust                |
|--------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|
| **v1** | UNK                      | ERR                      | ND                       | UNK                      | UNK                      | FN                       | TN                       | ND                       | ND                       | TN                       |
| **v2** | UNK                      | UNK                      | ND                       | UNK                      | UNK                      | UNK                      | TN!                      | ND                       | ND                       | TN!                      |
| **v3** | UNK                      | TP!                      | ND                       | UNK                      | TP!                      | TP!                      | UNK                      | ND                       | ND                       | UNK                      |
 

#### ELD
|        | fair-split               | fair-split-for-v3        | funds-get-transferred     | non-zero-payees          | positive-shares          | releasable-balance-check | releasable-sum-balance   | release-release-revert   | swappable-call-order     | zero-dust                |
|--------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|
| **v1** | UNK                      | ERR                      | ND                       | UNK                      | UNK                      | UNK                      | UNK                      | ND                       | ND                       | UNK                      |
| **v2** | UNK                      | UNK                      | ND                       | UNK                      | UNK                      | UNK                      | UNK                      | ND                       | ND                       | UNK                      |
| **v3** | TP!                      | TP!                      | ND                       | TP!                      | TP!                      | TP!                      | TN!                      | ND                       | ND                       | TN!                      |
 


### Certora
|        | fair-split               | fair-split-for-v3        | funds-get-transferred     | non-zero-payees          | positive-shares          | releasable-balance-check | releasable-sum-balance   | release-release-revert   | swappable-call-order     | zero-dust                |
|--------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|--------------------------|
| **v1** | TP!                      | TN                       | TN                       | FN                       | TP!                      | TP!                      | FP!                      | TP!                      | FP!                      | TN                       |
| **v2** | TP!                      | TN                       | TN                       | FN                       | FN                       | FN                       | TN                       | TP!                      | TN                       | TN                       |
| **v3** | FN                       | TP!                      | TN                       | FN                       | TP!                      | FN                       | TN                       | TP!                      | TN                       | TN                       |
 

