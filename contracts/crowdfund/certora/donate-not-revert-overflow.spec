rule donate_not_revert_overflow {
    env e;
    
    require(e.block.number <= getEndDonate());

    mathint n = getDonated(e.msg.sender);
    require(n < max_uint - e.msg.value);

    donate@withrevert(e);    

    assert !lastReverted;
}
