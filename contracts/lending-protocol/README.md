# Lending protocol

## Specification
TODO

## Properties
- **borrow-additivity**: if some sender A can perform two (successful) `borrow` of n1 and n2 token units (of the same token T), then A can always obtain an equivalent effect (on the state of the contract and on its own token balance) through a single `borrow` of n1+n2 units of token T. Here equivalence neglects transaction fees.
- **borrow-post**: TODO
- **deposit-additivity**: if some sender A can perform two (successful) `deposit` of n1 and n2 token units (of the same token T), then A can always obtain an equivalent effect (on the state of the contract and on its own token balance) through a single `deposit` of n1+n2 units of token T. Here equivalence neglects transaction fees.
- **deposit-post**: TODO
- **trace1**: TODO
- **xr-geq-one**: for each token T handled by the lending protocol, the exchange rate XR(T) is always greater than or equal to 1000000
- **xr-invariant**: , for each token type T handled by the lending protocol, any transaction of type `deposit`, `borrow`, `repay` preserve the exchange rate XR(T). Here, assume that before performing the transaction, the interests have already been accrued, i.e. `lastAccrue` and `lastTotAccrue` coincide with the block number where the transaction is performed, for all token and users involved in the transaction.

## Versions
- **v1**: minimal implementation without liquidation

## Verification data

- [Ground truth](ground-truth.csv)
- [Solcmc/z3](solcmc-z3.csv)
- [Solcmc/Eldarica](solcmc-eld.csv)
- [Certora](certora.csv)

## Experiments
