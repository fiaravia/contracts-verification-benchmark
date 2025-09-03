// SPDX-License-Identifier: GPL-3.0-only

/// @custom:run certoraRun versions/PriceBet_v1.sol:PriceBet versions/PriceBet_v1.sol:Oracle --verify PriceBet:certora/win-not-revert.spec --link PriceBet:oracle=Oracle

// a transaction win() does not revert if:
// 1) the deadline has not expired, and
// 2) the sender is the player, and 
// 3) the oracle exchange rate is greater or equal to the bet exchange rate.

using Oracle as oracle;

rule win_not_revert {
    env e;

    // technical assumption
    require currentContract.player != currentContract;

    require 
        e.msg.value == 0 &&
        e.block.number < currentContract.deadline &&
        e.msg.sender == currentContract.player &&
        oracle.exchange_rate >= currentContract.exchange_rate;
    
    win@withrevert(e);
    assert !lastReverted;
}
