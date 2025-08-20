// SPDX-License-Identifier: GPL-3.0-only

rule join_balance_geq {
    env e;

    // uint old_balance = nativeBalances[currentContract];
    uint initial_pot = currentContract.initial_pot;

    join(e);

    uint new_balance = nativeBalances[currentContract];

    assert new_balance >= 2 * initial_pot;
}
