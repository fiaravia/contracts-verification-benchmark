import "helper/methods.spec";

rule funds_get_transferred {
    env e; 
    address addr;

    uint index;
    address payee = getPayee(index);
    require getShares(payee) > 0;
    require releasable(payee) > 0;
    
    release@withrevert(e, payee);

    assert( !lastReverted );
}
