// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (finance/PaymentSplitter.sol)

pragma solidity ^0.8.0;

/// @custom:version loop-free version with a fixed number of payees (set to 3) and equal shares

contract PaymentSplitter_v3 {
    uint256 private constant PAYEES = 3;
    uint256 private numPayees = 0;

    uint256 private totalShares = 0;
    uint256 private totalReleased = 0;

    mapping(address => uint256) private shares;
    mapping(address => uint256) private released;
    address[] private payees;

    constructor(address payee1, address payee2, address payee3) payable {
        require(
            payee1 != address(0),
            "PaymentSplitter: account is the zero address"
        );
        require(
            shares[payee1] == 0,
            "PaymentSplitter: account already has shares"
        );

        payees.push(payee1);
        shares[payee1] = 1;
        released[payee1] = 0;
        totalShares = totalShares + 1;
        numPayees += 1;

        require(
            payee2 != address(0),
            "PaymentSplitter: account is the zero address"
        );
        require(
            shares[payee2] == 0,
            "PaymentSplitter: account already has shares"
        );

        payees.push(payee2);
        shares[payee2] = 1;
        released[payee2] = 0;
        totalShares = totalShares + 1;
        numPayees += 1;

        require(
            payee3 != address(0),
            "PaymentSplitter: account is the zero address"
        );
        require(
            shares[payee3] == 0,
            "PaymentSplitter: account already has shares"
        );

        payees.push(payee3);
        shares[payee3] = 1;
        released[payee3] = 0;
        totalShares = totalShares + 1;
        numPayees += 1;
    }

    receive() external payable virtual {}

    function releasable(address account) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + totalReleased;
        return pendingPayment(totalReceived, released[account]);
    }

    function release(address payable account) public virtual {
        require(shares[account] > 0, "PaymentSplitter: account has no shares");
        require(isPayee(account));

        uint256 payment = releasable(account);

        require(payment != 0, "PaymentSplitter: account is not due payment");

        // totalReleased is the sum of all values in released.
        // If "totalReleased += payment" does not overflow, then "released[account] += payment" cannot overflow.
        totalReleased += payment;
        unchecked {
            released[account] += payment;
        }

        (bool success, ) = account.call{value: payment}("");
        require(success);
    }

    function pendingPayment(
        uint256 totalReceived,
        uint256 alreadyReleased
    ) private pure returns (uint256) {
        return (totalReceived / PAYEES) - alreadyReleased;
    }

    // Getters

    function isPayee(address a) public view returns (bool) {
        for (uint i; i < PAYEES; i++) if (payees[i] == a) return true;
        return false;
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function getTotalReleasable() public view returns (uint) {
        uint _total_releasable = 0;

        _total_releasable += releasable(payees[0]);
        _total_releasable += releasable(payees[1]);
        _total_releasable += releasable(payees[2]);

        return _total_releasable;
    }

    function getPayee(uint index) public view returns (address) {
        require(index < 3);
        return payees[index];
    }

    function getShares(address addr) public view returns (uint) {
        if (isPayee(addr)) {
            return 1;
        }
        return 0;
    }

    function getReleased(address addr) public view returns (uint) {
        return released[addr];
    }

    function getSumOfShares() public view returns (uint) {
        uint sum = 0;

        sum += getShares(payees[0]);
        sum += getShares(payees[1]);
        sum += getShares(payees[0]);

        return sum;
    }

    function getSumOfReleased() public view returns (uint) {
        uint sum = 0;

        sum += released[payees[0]];
        sum += released[payees[1]];
        sum += released[payees[2]];

        return sum;
    }

    function getPayeesLength() public pure returns (uint) {
        return PAYEES;
    }

    function getTotalShares() public view returns (uint) {
        return totalShares;
    }
}
