// SPDX-License-Identifier: GPL-3.0-only

ghost mathint sum_credits { init_state axiom sum_credits==0; }

hook Sstore credits[KEY address a] uint new_value (uint old_value) {
    if (a!=currentContract) {
        sum_credits = sum_credits - old_value + new_value;
    }
}

invariant credits_leq_balance()
    sum_credits <= nativeBalances[currentContract];
