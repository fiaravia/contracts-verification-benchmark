
// SPDX-License-Identifier: GPL-3.0-only

// a transaction join() does not revert if: 
// 1) the ETH amount sent along with the transaction is equal to initial pot, and
// 2) no player has joined yet, and 
// 3) the deadline has not passed yet.


rule join_not_revert {
    env e;

    uint initial_pot = currentContract.initial_pot;
    uint deadline = currentContract.deadline;
    address player = currentContract.player;

    require
        nativeBalances[e.msg.sender] >= e.msg.value && // this condition is necessary
        e.msg.value == initial_pot &&
        player == 0x0 &&
        e.block.number < deadline &&
        e.msg.sender != 0x0;

    join@withrevert(e);
    assert !lastReverted;
}
