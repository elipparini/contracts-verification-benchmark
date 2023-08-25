// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >= 0.8.2;
import "./lib/ReentrancyGuard.sol";

contract Caller is ReentrancyGuard {
    uint data;

    function callyourself() public nonReentrant {
        msg.sender.call("");
    }
    
    // p2
    function invariant() public {
        uint _data = data;
        callyourself();
        assert(_data == data);
    }
}