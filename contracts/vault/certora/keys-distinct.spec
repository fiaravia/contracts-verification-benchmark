// SPDX-License-Identifier: GPL-3.0-only

// the owner key and the recovery key are distinct.

invariant keys_distinct()
    currentContract.owner != currentContract.recovery;


