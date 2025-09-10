
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract AttackerGuard {
    event Checked(bytes32 txHash, bool success);

    function checkTransaction(
        address /*to*/,
        uint256 /*value*/,
        bytes calldata /*data*/,
        uint8 /*operation*/,
        uint256 /*safeTxGas*/,
        uint256 /*baseGas*/,
        uint256 /*gasPrice*/,
        address /*gasToken*/,
        address payable /*refundReceiver*/,
        bytes calldata /*signatures*/,
        address /*msgSender*/
    ) external {}

    function checkAfterExecution(bytes32 txHash, bool success) external {
        emit Checked(txHash, success);
    }
}
