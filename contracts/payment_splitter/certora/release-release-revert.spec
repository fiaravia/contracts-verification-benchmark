import "helper/methods.spec";

rule release_release_revert {
    env e1; 
    uint index;
    address addr = getPayee(index);

    mathint released = releasable(addr);
    mathint balanceBefore = getBalance();

    release(e1, addr); // First release call

    mathint balanceAfter = getBalance();

    // Forces CVL to not assume that release() caused a transaction to this contract
    require balanceAfter == balanceBefore - released;  // This require also makes sure that the first call does not revert

    release@withrevert(e1,addr); // Second release call, should revert
    assert lastReverted;
}




