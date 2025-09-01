/// @custom:ghost
address prev_player;

function read_player() public {
    prev_player = player;
}

function player_immutable() public view {
    assert (prev_player == ZERO_ADDRESS || prev_player == player);   
}
