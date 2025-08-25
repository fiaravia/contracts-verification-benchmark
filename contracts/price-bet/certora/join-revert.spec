// SPDX-License-Identifier: GPL-3.0-only

// a transaction join() reverts if: 
// 1) the amount sent is different from initial_pot, or 
// 2) another player has already joined, or
// 3) the deadline has passed

rule join_revert {
    env e;

    require 
        e.msg.value != currentContract.initial_pot ||
        currentContract.player != 0 ||
        e.block.number >= currentContract.deadline;

    join@withrevert(e);
    assert lastReverted;
}
