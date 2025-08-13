// Lemma 3.3 of "A theory of Lending Protocols in DeFi"
    
// --model-checker-ext-calls trusted

function invariant(address t) public view {
    require(isValidToken(t));
    assert(
            totCredit[t] != 0 ||
            (totDebit[t] == 0 && reserves[t] == 0)
    );
}