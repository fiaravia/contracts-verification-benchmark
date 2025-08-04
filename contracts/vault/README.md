# Vault

## Specification
Vaults are a security mechanism to prevent cryptocurrency from being immediately withdrawn by an adversary who has stolen the owner's private key.

To create the vault, the owner specifies:
- itself as the vault's **owner**; 
- a **recovery key**, which can be used to cancel a withdraw request;
- a **wait time**, which has to elapse between a withdraw request and the actual finalization of the cryptocurrency transfer.

The contract has the following entry points:
- **receive(amount)**, which allows anyone to deposit tokens into the contract;
- **withdraw(receiver, amount)**, which allows the owner to issue a withdraw request, specifying the receiver and the desired amount;
- **finalize()**, which allows the owner to finalize the pending withdraw after the wait time has passed since the request;
- **cancel()**, which allows the owner of the recovery key to cancel the withdraw request during the wait time.

To this purpose, the vault contract implements a state transition system with states IDLE and REQ, and transitions: 
- IDLE -> IDLE upon a receive action
- IDLE -> REQ upon a withdraw action
- REQ -> REQ upon a receive action
- REQ -> IDLE upon a finalize or a cancel action

## Properties
- **cancel-not-revert**: a transaction `cancel()` does not abort if the signer uses the recovery key, and the state is REQ.
- **cancel-revert**: a transaction `cancel()` aborts if the signer uses a key different from the recovery key, or the state is not REQ.
- **finalize-assets-transfer**: after a successful `finalize()`, exactly amount units of T pass from the control of the contract to that of the receiver.
- **finalize-before-deadline-revert**: a `finalize()` transaction called immediately after a successful `withdraw()` aborts if sent before wait_time units have elapsed since the `withdraw()`.
- **finalize-not-revert**: a transaction `finalize()` aborts if the sender is not the owner, or if the state is not REQ, or wait_time has not passed since request_time.
- **finalize-or-cancel-twice-revert**: a `finalize()` or `cancel()` transaction aborts if performed immediately after another `finalize()` or `cancel()`.
- **finalize-revert**: a transaction `finalize()` aborts if the sender is not the owner, or if the state is not REQ, or wait_time has not passed since request_time.
- **keys-distinct**: the owner key and the recovery key are distinct.
- **keys-invariant-inter**: in any blockchain state, the owner key and the recovery key cannot be changed after the contract is deployed.
- **keys-invariant-intra**: during the execution of a transaction, the owner key and the recovery key cannot be changed after the contract is deployed.
- **okey-rkey-private-withdraw**: if an actor holds both the owner and recovery key, and no one else knows the recovery key, the former is able to eventually withdraw all the contract balance with probability 1 (for every fair trace).
- **receive-not-revert**: anyone can always send tokens to the contract
- **rkey-no-withdraw**: if an actor holds the recovery key, they can always prevent other actors from withdrawing funds from the contract.
- **state-idle-req-inter**: in any blockchain state, the vault state is IDLE or REQ
- **state-idle-req-intra**: during the execution of a transaction, the vault state is always IDLE or REQ.
- **state-req-amount-consistent**: if the state is REQ, then the amount to be withdrawn is less than or equal to the contract balance.
- **state-update**: the contract implements a state machine with transitions: s -> s upon a receive (for any s), IDLE -> REQ upon a withdraw, REQ -> IDLE upon a finalize or a cancel.
- **tx-idle-req**: if the state is IDLE, someone can fire a transaction that updates the state to REQ.
- **tx-owner-assets-transfer**: if the state is REQ and wait_time has passed since request_time, the owner can fire a transaction that transfers the contract balance to the receiver.
- **tx-recovery-cancel**: if the state is REQ and wait_time has not passed since request_time, the recovery key can fire a transaction that cancels the withdraw, resetting the state to IDLE.
- **tx-tx-assets-transfer**: in any state, someone can fire a sequence of two transactions that transfers the contract balance to the receiver.
- **withdraw-finalize-not-revert**: a `finalize()` transaction called immediately after a successful `withdraw()` does not abort if sent after wait_time units have elapsed.
- **withdraw-finalize-revert-inter**: a `finalize` transaction called before `wait_time` since a successful `withdraw`, possibly with in-between transactions, reverts.
- **withdraw-not-revert**: a transaction `withdraw(amount)` does not abort if amount is less than or equal to the contract balance, the sender is the owner, and the state is IDLE.
- **withdraw-revert**: a transaction `withdraw(amount)` aborts if amount is more than the contract balance, or if the sender is not the owner, or if the state is not IDLE.
- **withdraw-withdraw-revert**: a transaction `withdraw()` aborts if performed immediately after another `withdraw()`.

## Versions
- **v1**: conforming to specification.
- **v2**: require in constructor wrongly uses state variable instead of parameter.
- **v3**: removed the time constraint on `finalize`.

## Verification data

- [Ground truth](ground-truth.csv)
- [Solcmc/z3](solcmc-z3.csv)
- [Solcmc/Eldarica](solcmc-eld.csv)
- [Certora](certora.csv)