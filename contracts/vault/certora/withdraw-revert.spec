// SPDX-License-Identifier: GPL-3.0-only

// withdraw-revert: a transaction withdraw(amount) aborts if:
// 1) amount is more than the contract balance, or 
// 2) the sender is not the owner, or 
// 3) the state is not IDLE.

rule withdraw_revert {
    env e;
    uint amt;
    address rcv;

    require 
        amt > nativeBalances[currentContract] ||
        e.msg.sender != currentContract.owner || 
        currentContract.state != Vault.States.IDLE;

    withdraw@withrevert(e, rcv, amt);
    assert lastReverted;
}
