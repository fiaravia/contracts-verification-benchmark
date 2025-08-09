// SPDX-License-Identifier: GPL-3.0-only

rule deposit_contract_balance {
    env e;

    // This require is necessary to ensure that verification succeeds
    // However, the contract ensures that the sender of a deposit cannot the contract itself
    require e.msg.sender != currentContract;

    mathint old_contract_balance = nativeBalances[currentContract];
    deposit(e);
    mathint new_contract_balance = nativeBalances[currentContract];

    assert new_contract_balance == old_contract_balance + e.msg.value;
}
