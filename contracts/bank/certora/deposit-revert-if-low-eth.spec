// SPDX-License-Identifier: GPL-3.0-only

rule deposit_revert_if_low_eth {
    env e;

    require(e.msg.value > nativeBalances[e.msg.sender]);
    deposit@withrevert(e);
    
    assert lastReverted;
}
