// SPDX-License-Identifier: GPL-3.0-only

rule owner_cannot_withdraw_before_deadline {
    env e;
    method f;
    calldataarg args;

    // address of the user who will receive the tokens
    address a;

    require e.block.number < currentContract.deadline;

    uint owner_balance_before = nativeBalances[currentContract.owner];

    f(e, args);

    uint owner_balance_after = nativeBalances[currentContract.owner];

    assert owner_balance_after <= owner_balance_before;
}
