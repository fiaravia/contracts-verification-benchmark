// releasable-sum-balance invariant 
function invariant() public view {
    assert(getTotalReleasable() == address(this).balance);
}