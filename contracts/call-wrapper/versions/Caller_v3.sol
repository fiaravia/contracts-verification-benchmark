// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >= 0.8.2;

/// @custom:version reentrant `callwrap` and additional reentrant function `modifystorage`.
contract CallWrapper {
    uint data = 0;

    function callwrap(address called) public {
        called.call("");
    }

    function modifystorage(uint newdata) public {
        data = newdata;
    }

}