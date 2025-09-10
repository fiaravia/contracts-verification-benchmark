// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (finance/PaymentSplitter.sol)

pragma solidity ^0.8.0;

/// @custom:version loop-free version with a fixed number of payees (set to 3)

contract PaymentSplitter {
    uint256 private constant PAYEES = 3;
    uint256 private numPayees = 0;

    uint256 private totalShares;
    uint256 private totalReleased;

    mapping(address => uint256) private shares;
    mapping(address => uint256) private released;
    address[] private payees;

    // workaround for bug in solc v0.8.30
    address constant ZERO_ADDRESS = address(0x0000000000000000000000000000000000000000);

    constructor(
        address payee1,
        uint256 shares1,
        address payee2,
        uint256 shares2,
        address payee3,
        uint256 shares3
    ) payable {
        addPayee(payee1, shares1);
        addPayee(payee2, shares2);
        addPayee(payee3, shares3);
    }

    receive() external payable virtual {}

    function releasable(address account) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + totalReleased;
        return pendingPayment(account, totalReceived, released[account]);
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
        address account,
        uint256 totalReceived,
        uint256 alreadyReleased
    ) private view returns (uint256) {
        return
            (totalReceived * shares[account]) / totalShares - alreadyReleased;
    }

    function addPayee(address account, uint256 shares_) private {
        require(numPayees < PAYEES);

        require(
            account != ZERO_ADDRESS,
            "PaymentSplitter: account is the zero address"
        );
        require(shares_ > 0, "PaymentSplitter: shares are 0");
        require(
            shares[account] == 0,
            "PaymentSplitter: account already has shares"
        );

        payees.push(account);
        shares[account] = shares_;
        totalShares = totalShares + shares_;
        numPayees += 1;
    }

    // Getters

    function isPayee(address a) public view returns (bool) {
        return (a == getPayee(0) || a == getPayee(1) || a == getPayee(2));
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
        require(index < payees.length);
        return payees[index];
    }

    function getShares(address addr) public view returns (uint) {
        require(isPayee(addr));
        return shares[addr];
    }

    function getReleased(address addr) public view returns (uint) {
        return released[addr];
    }

    function getSumOfShares() public view returns (uint) {
        uint sum = 0;

        sum += shares[payees[0]];
        sum += shares[payees[1]];
        sum += shares[payees[2]];

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
