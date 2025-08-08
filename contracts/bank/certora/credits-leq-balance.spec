// SPDX-License-Identifier: GPL-3.0-only

// the assets controlled by the contract are (at least) equal to the sum of all the user balances


ghost mathint sum_balances { init_state axiom sum_balances==0; }

hook Sstore balances[KEY address a] uint new_value (uint old_value) {
    if (a!=currentContract) {
        sum_balances = sum_balances - old_value + new_value;
    }
}

invariant balances_leq_balance()
    nativeBalances[currentContract] >= sum_balances;
