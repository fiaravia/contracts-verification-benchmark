// SPDX-License-Identifier: GPL-3.0-only

rule finalize_assets_transfer_receive {
    env e;

    address receiver = currentContract.receiver;
    uint amount = currentContract.amount;

    uint old_receiver_balance = nativeBalances[receiver];
    uint old_contract_balance = nativeBalances[currentContract];

    // technical assumption
    require (receiver != currentContract);

    finalize(e);

    uint new_receiver_balance = nativeBalances[receiver];
    uint new_contract_balance = nativeBalances[currentContract];

    assert new_receiver_balance == old_receiver_balance + amount;
    assert new_contract_balance == old_contract_balance - amount;
}
