function getBalance() public view returns (uint256) {
    return address(this).balance;
}

function getDuration() public view returns (uint64) {
    return duration;
}

function getStart() public view returns (uint64) {
    return start;
}
