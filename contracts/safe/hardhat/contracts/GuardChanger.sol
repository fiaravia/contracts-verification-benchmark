// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract GuardChanger {
    function change(address newGuard) external {
        bytes32 slot = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8; // GUARD_STORAGE_SLOT
        assembly {
            sstore(slot, newGuard)
        }
    }
}
