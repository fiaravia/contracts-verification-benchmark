// SPDX-License-Identifier: GPL-3.0-only

// it is always possible to send assets to the contract

rule receive_not_revert {
    env e;
    method f;
    calldataarg args;

    require f.isFallback;
    require e.msg.sender != currentContract;
    require e.msg.value > 0;

    mathint old_contract_balance = nativeBalances[currentContract];
    f(e, args);
    assert nativeBalances[currentContract] > old_contract_balance;
}
