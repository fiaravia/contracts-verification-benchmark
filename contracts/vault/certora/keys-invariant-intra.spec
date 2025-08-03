// SPDX-License-Identifier: GPL-3.0-only

// during the execution of a transaction, the owner key and the recovery key cannot be changed after the contract is deployed

ghost bool owner_unchanged { init_state axiom owner_unchanged; }
ghost bool recovery_unchanged { init_state axiom recovery_unchanged; }

hook Sstore owner address new_addr (address old_addr) {
    if (old_addr != 0 && new_addr != old_addr) owner_unchanged = false;
}

hook Sstore recovery address new_addr (address old_addr) {
    if (old_addr != 0 && new_addr != old_addr) recovery_unchanged = false;
}

invariant keys_invariant_local()
    owner_unchanged && recovery_unchanged;
