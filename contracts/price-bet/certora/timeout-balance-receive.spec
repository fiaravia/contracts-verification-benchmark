// SPDX-License-Identifier: GPL-3.0-only

rule timeout_balance_receive {
    env e;
    
    uint prev_contract_balance = nativeBalances[currentContract];
    uint prev_owner_balance = nativeBalances[currentContract.owner];

    // technical assumption
    require currentContract.owner != currentContract;

    timeout(e);
    assert nativeBalances[currentContract.owner] == prev_owner_balance + prev_contract_balance;
}
