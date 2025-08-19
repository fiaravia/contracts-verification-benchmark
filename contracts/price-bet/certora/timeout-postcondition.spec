// SPDX-License-Identifier: GPL-3.0-only

/// @custom:run certoraRun versions/PriceBet_v1.sol:PriceBet --verify PriceBet:certora/timeout-postcondition.spec

rule timeout_postcondition {
    env e;
    
    uint prev_contract_balance = nativeBalances[currentContract];
    uint prev_owner_balance = nativeBalances[currentContract.owner];

    timeout(e);
    assert nativeBalances[currentContract.owner] == prev_owner_balance + prev_contract_balance;
}
