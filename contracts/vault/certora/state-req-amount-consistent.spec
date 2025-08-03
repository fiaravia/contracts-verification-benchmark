// SPDX-License-Identifier: GPL-3.0-only

// if the state is REQ, then the amount to be withdrawn is less than or equal to the contract balance

invariant state_req_amount_consistent()
    currentContract.state==Vault.States.REQ => currentContract.amount <= nativeBalances[currentContract];

