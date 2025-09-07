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
- **cancel-not-revert**: a `cancel()` transaction does not revert if the sender uses the recovery key, and the state is REQ.
- **cancel-revert**: a `cancel()` transaction reverts if the signer uses a key different from the recovery key, or the state is not REQ.
- **finalize-assets-transfer**: after a non-reverting `finalize()`, exactly `amount` wei are transferred from the contract balance to the receiver.
- **finalize-assets-transfer-receive**: after a non-reverting `finalize()`, if the `receive` method of `receiver` just accepts all ETH, then exactly `amount` wei are transferred from the contract to the receiver.
- **finalize-before-deadline-revert**: a `finalize()` transaction called immediately after a non-reverting `withdraw()` recerts if sent before `wait_time` blocks have elapsed since the call to `withdraw()`.
- **finalize-not-revert**: a `finalize()` transaction does not revert if it is sent by the owner, in state REQ, and at least `wait_time` blocks have elapsed after `request_timestamp`.
- **finalize-not-revert-eoa**: a `finalize()` transaction does not revert if it is sent by the owner, in state REQ, at least `wait_time` blocks have elapsed after `request_timestamp`, and the `receiver` is an EOA.
- **finalize-or-cancel-twice-revert**: a `finalize()` or `cancel()` transaction reverts if performed immediately after another `finalize()` or `cancel()`.
- **finalize-revert**: a `finalize()` transaction reverts if the sender is not the owner, or if the state is not REQ, or `wait_time` blocks have not passed since request_time.
- **finalize-sent-eq-amount**: after a non-reverting `finalize()`, the contract balance is decreased by exactly `amount` wei.
- **finalize-sent-leq-amount**: after a non-reverting `finalize()`, the contract balance is decreased by at most `amount` wei.
- **keys-distinct**: in any contract state, the owner key and the recovery key are distinct.
- **keys-invariant-inter**: after the contract is deployed, in any blockchain state the owner key and the recovery key cannot be changed.
- **keys-invariant-intra**: after the contract is deployed, during the execution of a transaction, the owner key and the recovery key cannot be changed.
- **okey-rkey-private-withdraw**: if some user A knows both the owner and recovery key, and no one else knows the recovery key, then (in every fair trace) A is able to eventually transfer to any EOA of her choice any fraction of the contract balance, while no one else has the same ability. Assume `wait_time` is small enough to avoid overflows
- **receive-not-revert**: anyone can always send tokens to the contract
- **rkey-no-withdraw**: if some user knows the recovery key, they can always prevent other users from withdrawing funds from the contract.
- **state-idle-req-inter**: in any blockchain state, the Vault state is IDLE or REQ
- **state-idle-req-intra**: during the execution of a transaction, the Vault state is always IDLE or REQ.
- **state-req-amount-consistent**: if the state is REQ, then `amount` is less than or equal to the contract balance.
- **state-update**: the contract implements a state machine with transitions: s -> s upon a `receive` (for any s), IDLE -> REQ upon a `withdraw`, REQ -> IDLE upon a `finalize` or a `cancel`.
- **state-update-receive**: if the `receive` method of `receiver` just accepts all ETH, the contract implements a state machine with transitions: s -> s upon a receive (for any s), IDLE -> REQ upon a withdraw, REQ -> IDLE upon a finalize or a cancel.
- **tx-idle-req**: if the state is IDLE, someone can fire a transaction that updates the state to REQ.
- **tx-idle-req-eoa**: if the state is IDLE and `owner` is an EOA, someone can fire a transaction that updates the state to REQ.
- **tx-owner-assets-transfer**: if the state is REQ and `wait_time` has passed since `request_time`, the `owner` can fire a transaction that transfers `amount` wei from the Vault to the `receiver`.
- **tx-owner-assets-transfer-eoa**: if the state is REQ, `wait_time` has passed since `request_time`, and both `owner` and `receiver` are EOAs, then the owner can fire a transaction that transfers `amount` wei from the Vault to the receiver.
- **tx-req-idle**: if the state is REQ, someone can fire a transaction that updates the state to IDLE.
- **tx-req-idle-eoa**: if the state is REQ and the recovery address passed to the constructor is a non-zero EOA, someone can fire a transaction that updates the state to IDLE.
- **tx-tx-assets-transfer**: in state IDLE, someone can fire a sequence of transactions that transfers the entire contract balance to a chosen EOA, regardless of possible transactions fired by the adversary before or in between.
- **tx-tx-assets-transfer-eoa**: if `owner` is an EOA, then in state IDLE, someone can fire a sequence of transactions that transfers the entire contract balance to a chosen EOA, regardless of possible transactions fired by the adversary before or in between.
- **tx-tx-assets-transfer-eoa-private**: if `owner` is an EOA and the adversary does not know the recovery key, then in state IDLE, the owner can fire a sequence of transactions that transfers the contract balance to a chosen EOA, regardless of possible transactions fired by the adversary before or in between.
- **withdraw-finalize-not-revert**: a `finalize()` transaction called by the `owner` after a non-reverting `withdraw()` (with no other transactions executed in between) does not revert if sent after `wait_time` blocks have elapsed.
- **withdraw-finalize-not-revert-eoa**: if the `receiver` is an EOA, a `finalize()` transaction called by the `owner` after a non-reverting `withdraw()` (with no other transactions executed in between) does not revert if sent after `wait_time` blocks have elapsed.
- **withdraw-finalize-revert-inter**: a `finalize` transaction called before `wait_time` since a non-reverting `withdraw`, possibly with in-between transactions, reverts.
- **withdraw-not-revert**: a `withdraw(amount)` transaction does not revert if `amount` is less than or equal to the contract balance, the sender is the owner, and the state is IDLE.
- **withdraw-revert**: a `withdraw(amount)` transaction reverts if `amount` is more than the contract balance, or if the sender is not the owner, or if the state is not IDLE.
- **withdraw-withdraw-revert**: a `withdraw()` transaction reverts if fired immediately after another `withdraw()`.

## Versions
- **v1**: minimal implementation conforming to specification.
- **v2**: the `require` in `constructor` wrongly checks the state variable `recovery` instead of the parameter `recovery_`.
- **v3**: removed time constraint in `finalize`.
- **v4**: `finalize` is non-reentrant.
- **v5**: missing access control that `msg.sender == recovery` in `cancel`. 
- **v6**: missing check `amount_ <= address(this).balance` in `withdraw`.
- **v7**: time constraint in `finalize` set to <= instead of >=.
- **v8**: `finalize` uses `transfer` instead of low-level call.
- **v9**: `cancel` updates the recovery key before checking `msg.sender`, and then restores it
- **v10**: `finalize` transfers `amount`-1.
- **v11**: `finalize` does not update the state, so it can be called twice consecutively.

## Verification data

- [Ground truth](ground-truth.csv)
- [Solcmc/z3](solcmc-z3.csv)
- [Solcmc/Eldarica](solcmc-eld.csv)
- [Certora](certora.csv)

