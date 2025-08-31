// SPDX-License-Identifier: GPL-3.0-only

rule owner_cannot_receive_before_deadline {
    env e;
    method f;
    calldataarg args;

    address owner = currentContract.owner;

    // the deadline has not passed yet
    require e.block.number < currentContract.deadline;

    uint owner_balance_before = nativeBalances[owner];

    f(e, args);

    uint owner_balance_after = nativeBalances[owner];

    // the owner cannot withdraw any ETH
    assert owner_balance_after <= owner_balance_before;
}
