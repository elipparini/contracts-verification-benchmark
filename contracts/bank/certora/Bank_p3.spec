methods {
    function getBalance(address) external returns(uint) envfree;
    function getContractBalance() external returns (uint) envfree;
    function withdraw(uint) external;
}

rule P3 {
    env e;

    address sender = e.msg.sender;
    uint amount;
    
    uint senderBalanceBefore = getBalance(sender);
    
    withdraw(e, amount);

    uint senderBalanceAfter = getBalance(sender);
    
    assert senderBalanceBefore > senderBalanceAfter;
}

// should fail
rule NotP3 {
    env e;

    address sender = e.msg.sender;
    uint amount;
    
    uint senderBalanceBefore = getBalance(sender);
    
    withdraw(e, amount);

    uint senderBalanceAfter = getBalance(sender);
    
    assert senderBalanceBefore <= senderBalanceAfter;
}

// proof V1: https://prover.certora.com/output/49230/b0692a36197f46cf8c65eaac820d3eba?anonymousKey=934acb96643456277d2daf4136a391a63a3fd1f7
// proof V2: https://prover.certora.com/output/49230/143f6491b0934c8781f7a691584319e5?anonymousKey=28f1f632c839d387ee1c275dbaae26a791151f3b