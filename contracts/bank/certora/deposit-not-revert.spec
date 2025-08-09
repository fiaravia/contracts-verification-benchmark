// SPDX-License-Identifier: GPL-3.0-only

rule deposit_not_revert {
    env e;

    deposit@withrevert(e);
    
    assert !lastReverted;
}
