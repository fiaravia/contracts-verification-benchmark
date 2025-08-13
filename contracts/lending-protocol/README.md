# Lending protocol

## Specification
The LP contract implements a lending protocol that allows users to deposit tokens as collateral, earn interest on deposits, and borrow tokens.

The LP contract handles ERC20-compatible tokens. No ETH is exchanged between the LP and its users. 
Credits and debits are not represented as tokens, but as maps within the contract state:
- **debits** represent debt tokens that track how much users owe. These accrue interest over time.
- **credits** represent claim tokens that users receive when depositing. They appreciate in value over time as interests accrue on debits.

## Main functions

### Deposit

The action `deposit(amount,t)` allows 
the sender to deposit `amount` units of token `t`, receiving in exchange units of the associated credit token. 
The actual amount of received units is the product between `amount` and the exchange rate `XR(t)`, which is determined as follows:

```
XR(t) = (reserves[t] + total_debits[t]) * 1,000,000 / total_credits[t]
```

### Borrow

The action `borrow(amount, t)` allows 
the sender to borrow `amount` tokens of `t`, provided that they remains over-collateralized after the action.

### Repay

The action `repay(amount, t)` allows 
the sender to repay their debt of `amount` units of token `t`.

### Redeem

The action `redeem(amount, t)` allows 
the sender to withdraw `amount` units of token `t` that they deposited before. After the action, the user must remain over-collateralized.

### Liquidate

The action `liquidate(amount, t_debit, debtor, t_credit)` allows
the sender to repay a debt of `amount` units of token `t_debit` of `debtor`, receiving in exchange units of token `t_credit` seized from `debtor`. 


## Properties
- **borrow-additivity**: if a sender A can perform two (successful) `borrow` of n1 and n2 token units (of the same token T), then A can always obtain an equivalent effect (on the state of the contract and on its own token balance) through a single `borrow` of n1+n2 units of token T. Here equivalence neglects transaction fees.
- **borrow-post**: TODO
- **borrow-reversibility**: if a sender A performs a (successful) `borrow`, then A can fire a transaction that restores the amount of credits and debts of A to the state before the `borrow`. Here, assume that before performing the first transaction, the interests have already been accrued, i.e. `lastAccrue` and `lastTotAccrue` coincide with the block number where the transaction is performed, for all token and users involved in the transaction.
- **deposit-additivity**: if a sender A can perform two (successful) `deposit` of n1 and n2 token units (of the same token T), then A can always obtain an equivalent effect (on the state of the contract and on its own token balance) through a single `deposit` of n1+n2 units of token T. Here equivalence neglects transaction fees.
- **deposit-post**: TODO
- **deposit-redeem-reverse**: if a sender A performs a (successful) `deposit` of n1 token units and then a (successful) `withdraw` of n1*1000000/XR(token_addr), then the amount of the credits and debts of A is restored to that in the state before the `deposit`. Here, assume that before performing the first transaction, the interests have already been accrued, i.e. `lastAccrue` and `lastTotAccrue` coincide with the block number where the transaction is performed, for all token and users involved in the transaction.
- **deposit-reversibility**: if a sender A performs a (successful) `deposit`, then A can fire a transaction that restores the amount of credits and debts of A to the state before the `deposit`. Here, assume that before performing the first transaction, the interests have already been accrued, i.e. `lastAccrue` and `lastTotAccrue` coincide with the block number where the transaction is performed, for all token and users involved in the transaction.
- **deposit-reversibility-collateralized**: if a sender A performs a (successful) `deposit`, and A is collateralized, then A can fire a transaction that restores the amount credits and debts of A to the state before the `deposit`. Here, assume that before performing the first transaction, the interests have already been accrued, i.e. `lastAccrue` and `lastTotAccrue` coincide with the block number where the transaction is performed, for all token and users involved in the transaction.
- **redeem-reversibility**: if a sender A performs a (successful) `redeem`, then A can fire a transaction that restores the amount of credits and debts of A to the state before the `redeem`. Here, assume that before performing the first transaction, the interests have already been accrued, i.e. `lastAccrue` and `lastTotAccrue` coincide with the block number where the transaction is performed, for all token and users involved in the transaction.
- **trace1**: TODO
- **withdraw-reversibility**: if a sender A performs a (successful) `withdraw`, then A can fire a transaction that restores the amount of credits and debts of A to the state before the `withdraw`. Here, assume that before performing the first transaction, the interests have already been accrued, i.e. `lastAccrue` and `lastTotAccrue` coincide with the block number where the transaction is performed, for all token and users involved in the transaction.
- **xr-geq-one**: for each token T handled by the lending protocol, the exchange rate XR(T) is always greater than or equal to 1000000
- **xr-invariant**: , for each token type T handled by the lending protocol, any transaction of type `deposit`, `borrow`, `repay` preserve the exchange rate XR(T). Here, assume that before performing the transaction, the interests have already been accrued, i.e. `lastAccrue` and `lastTotAccrue` coincide with the block number where the transaction is performed, for all token and users involved in the transaction.
- **zero-credits-implies-zero-debts**: for each token type T, if the sum of the credits in T of all users is zero, then also the sum of the debts in T of all users are zero
- **zero-credits-implies-zero-reserves**: for each token type T, if the sum of the credits in T of all users is zero, then also the reserves in T are zero

## Versions
- **v1**: minimal implementation without liquidation

## Verification data

- [Ground truth](ground-truth.csv)
- [Solcmc/z3](solcmc-z3.csv)
- [Solcmc/Eldarica](solcmc-eld.csv)
- [Certora](certora.csv)

