// SPDX-License-Identifier: GPL-3.0-only

/// @custom:run certoraRun versions/PriceBet_v1.sol:PriceBet versions/PriceBet_v1.sol:Oracle --verify PriceBet:certora/win-revert.spec --link PriceBet:oracle=Oracle

// a transaction win() reverts if:
// 1) the deadline has expired, or 
// 2) the sender is not the player, or 
// 3) the oracle exchange rate is smaller than the bet exchange rate.

using Oracle as oracle;

rule win_revert {
    env e;

    require 
        e.block.number > currentContract.deadline ||
        e.msg.sender != currentContract.player ||
        oracle.exchange_rate < currentContract.exchange_rate;
    
    win@withrevert(e);
    assert lastReverted;
}
