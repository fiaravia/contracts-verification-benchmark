// SPDX-License-Identifier: GPL-3.0-only

// after a successful finalize(), the contract balance is decreased by at most amount units of T.

rule finalize_sent_leq_amount {
    env e;
    uint256 amount;

    mathint old_contract_balance = nativeBalances[currentContract];

    finalize(e);

    mathint new_contract_balance = nativeBalances[currentContract];
    assert new_contract_balance >= old_contract_balance - currentContract.amount;
}