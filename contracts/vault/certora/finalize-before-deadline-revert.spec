// SPDX-License-Identifier: GPL-3.0-only

// a finalize() transaction called immediately after a successful withdraw() aborts if sent before wait_time units have elapsed since the withdraw()

rule finalize_before_deadline_revert {
    env e1;
    
    address addr;
    uint amt;
    withdraw(e1, addr, amt);

    env e2;
    require e2.block.number < e1.block.number + currentContract.wait_time;

    finalize@withrevert(e2);

    assert lastReverted;
}
