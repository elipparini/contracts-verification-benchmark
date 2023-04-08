// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >= 0.8.2;

contract Deposit {

    uint balance;
    uint sent;

    uint deposited;

    constructor () {
        balance = address(this).balance;
        deposited = address(this).balance;
    }

    receive() external payable {
        balance += msg.value;
        deposited += msg.value;
    }

    fallback() external payable {
        balance += msg.value;
        deposited += msg.value;
    }

    function withdraw(uint _amount) public {

        require(_amount <= balance);

        sent += _amount;
        balance -= _amount;

        uint succ = block.number % 2;

        if (succ == 0) {
            sent -= _amount;
            balance += _amount;
        }
    }

    function withdraw_all() public {

        uint amount = balance;

        sent += balance;
        balance = 0;

        uint succ = block.number % 2;

        if (succ == 0) {
            sent -= amount;
            balance += amount;
        }
    }

    function invariant() public view {
        assert(sent <= deposited);
    }
}
// ====
// SMTEngine: CHC
// Time: 7.94s
// Targets: "all"
// ----
