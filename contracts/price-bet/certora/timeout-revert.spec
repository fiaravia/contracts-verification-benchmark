// SPDX-License-Identifier: GPL-3.0-only

/// @custom:run certoraRun versions/PriceBet_v1.sol:PriceBet --verify PriceBet:certora/timeout-revert.spec

// a transaction timeout() reverts if the deadline has not passed yet

rule timeout_revert {
    env e;

    require 
        e.block.number < currentContract.deadline;
    
    timeout@withrevert(e);
    assert lastReverted;
}
