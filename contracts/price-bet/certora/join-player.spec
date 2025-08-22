// SPDX-License-Identifier: GPL-3.0-only

rule join_player {
    env e;

    join(e);

    address new_player = currentContract.player; 

    assert new_player != 0x0;
}
