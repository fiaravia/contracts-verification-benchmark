// SPDX-License-Identifier: GPL-3.0-only

rule withdraw_finalize_not_revert {
    env e1;  

    address addr;
    uint amt;
    withdraw(e1, addr, amt);

    // technical assumption
    require (currentContract.receiver != currentContract);

    env e2;

    require 
        e2.msg.sender == currentContract.owner && 
        currentContract.state == Vault.States.REQ &&
        e2.block.number >= e1.block.number + currentContract.wait_time;

    finalize@withrevert(e2);

    assert !lastReverted;
}
