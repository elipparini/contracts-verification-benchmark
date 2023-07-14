// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >= 0.8.2;

contract Vault {
    enum States{IDLE, REQ}

    address owner;
    address recovery;
    uint wait_time;

    address receiver;
    uint request_time;
    uint amount;
    States state;

    // v2
    constructor (address payable recovery_, uint wait_time_) payable {
	    require(msg.sender != recovery); // ERROR: uses state variable instead of parameter
        owner = msg.sender;
        recovery = recovery_;
        wait_time = wait_time_;
        state = States.IDLE;
    }

    receive() external payable { }

    function getOwner() public view returns (address) {
        return owner;
    }

    function getRecovery() public view returns (address) {
        return recovery;
    }

    function getState() public view returns (States) {
        return state;
    }

    function getAmount() public view returns (uint) {
        return amount;
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function withdraw(address receiver_, uint amount_) public {
        require(state == States.IDLE);
        require(amount_ <= address(this).balance);
        require(msg.sender == owner);

        request_time = block.number;
        amount = amount_;
        receiver = receiver_;
        state = States.REQ;
    }

    function finalize() public { 
        require(state == States.REQ);
        require(block.number >= request_time + wait_time);
        require(msg.sender == owner);

        state = States.IDLE;	
        (bool succ,) = receiver.call{value: amount}("");
        require(succ);
    }

    function cancel() public {
        require(state == States.REQ);
        require(msg.sender == recovery);

        state = States.IDLE;
    }
}
