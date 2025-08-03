// SPDX-License-Identifier: GPL-3.0-only

// (in any blockchain state) the vault state is IDLE or REQ

invariant state_idle_req_global()
    currentContract.state == Vault.States.IDLE || currentContract.state == Vault.States.REQ;

