// SPDX-License-Identifier: GPL-3.0-only

// a finalize() or cancel() transaction aborts if performed immediately after another finalize() or cancel()

rule finalize_or_cancel_twice_revert {
    env e1;
    bool b1;
    if (b1) {
        finalize(e1);
    } else {
        cancel(e1);
    }
    
    env e2;
    bool b2;
    if (b2) {
        finalize@withrevert(e2);
    } else {
        cancel@withrevert(e2);
    }
    
    assert lastReverted;
}
