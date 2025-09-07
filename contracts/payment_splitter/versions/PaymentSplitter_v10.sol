// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (finance/PaymentSplitter.sol)

pragma solidity ^0.8.0;

/// @custom:version shares capped at 10000, refuses more than 999_999_999_999_999 wei

contract PaymentSplitter {
    uint256 private totalShares;
    uint256 private totalReleased;

    mapping(address => uint256) private shares;
    mapping(address => uint256) private released;
    address[] private payees;

    uint256 constant MAX_RECEIVED = 999_999_999_999_999;

    // workaround for bug in solc v0.8.30
    address constant ZERO_ADDRESS = address(0x0000000000000000000000000000000000000000);

    constructor(address[] memory payees_, uint256[] memory shares_) payable {
        require(
            payees_.length == shares_.length,
            "PaymentSplitter: payees and shares length mismatch"
        );
        require(payees_.length > 0, "PaymentSplitter: no payees");

        for (uint256 i = 0; i < payees_.length; i++) {
            addPayee(payees_[i], shares_[i]);
        }

        require(totalShares < 10000);
    }

    receive() external payable virtual {
        require(stateCheck());
        //require(address(this).balance + totalReleased + msg.value <= MAX_RECEIVED);
    }

    function releasable(address account) public view returns (uint256) {
        require(stateCheck());
        uint256 totalReceived = address(this).balance + totalReleased;
        return pendingPayment(account, totalReceived, released[account]);
    }

    function release(address payable account) public virtual {
        require(stateCheck());
        require(shares[account] > 0, "PaymentSplitter: account has no shares");

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
        require(stateCheck());
        return
            (totalReceived * shares[account]) / totalShares - alreadyReleased;
    }

    function addPayee(address account, uint256 shares_) private {
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
    }

    // Getters

    function isPayee(address a) public view returns (bool) {
        require(stateCheck());
        for (uint i; i < payees.length; i++) if (payees[i] == a) return true;
        return false;
    }

    function getBalance() public view returns (uint) {
        require(stateCheck());
        return address(this).balance;
    }

    function getTotalReleasable() public view returns (uint) {
        require(stateCheck());
        uint _total_releasable = 0;
        for (uint i = 0; i < payees.length; i++) {
            _total_releasable += releasable(payees[i]);
        }
        return _total_releasable;
    }

    function getPayee(uint index) public view returns (address) {
        require(stateCheck());
        require(index < payees.length);
        return payees[index];
    }

    function getShares(address addr) public view returns (uint) {
        require(stateCheck());
        return shares[addr];
    }

    function getReleased(address addr) public view returns (uint) {
        require(stateCheck());
        return released[addr];
    }

    function getSumOfShares() public view returns (uint) {
        require(stateCheck());
        uint sum = 0;
        for (uint i = 0; i < payees.length; i++) {
            sum += shares[payees[i]];
        }
        require(sum <= 10000);
        return sum;
    }

    function getSumOfReleased() public view returns (uint) {
        require(stateCheck());
        uint sum = 0;
        for (uint i = 0; i < payees.length; i++) {
            sum += released[payees[i]];
        }
        return sum;
    }

    function getPayeesLength() public view returns (uint) {
        require(stateCheck());
        return payees.length;
    }

    function getTotalShares() public view returns (uint) {
        require(stateCheck());
        return totalShares;
    }

    function stateCheck() public view returns (bool){
        return (totalShares <= 10000) && (address(this).balance + totalReleased <= MAX_RECEIVED);
    }
}
