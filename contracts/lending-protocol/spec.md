The LendingProtocol contract implements a lending protocol that allows users to deposit tokens as collateral, earn interest on deposits, and borrow tokens.

The LendingProtocol contract handles ERC20-compatible tokens. No ETH is exchanged between the LendingProtocol and its users. 
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
