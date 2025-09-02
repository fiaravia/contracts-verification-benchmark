// SPDX-License-Identifier: GPL-3.0-only

/// @custom:run certoraRun versions/PriceBet_v1.sol:PriceBet --verify PriceBet:certora/timeout-not-revert.spec

// a transaction timeout() does not revert if the deadline has passed

rule timeout_not_revert {
    env e;

    // technical assumption
    require currentContract.owner != currentContract;

    require 
        e.msg.value == 0 &&
        e.block.number >= currentContract.deadline;
    
    timeout@withrevert(e);
    assert !lastReverted;
}
