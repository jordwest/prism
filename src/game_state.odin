package main

SharedState:: struct {
	t:                  f32,
	width:              i32,
	height:             i32,
	other_pointer_down: u8,
	client:             ClientState,
	host:               HostState,
}

ClientState :: struct {
    cursor_pos:         [2]i32,
    my_token:           PlayerToken,
	player_id:          PlayerId,
    players:            map[PlayerId]Player,
	entities:           map[EntityId]Entity,
}

HostState :: struct {
	is_host:          bool,
	newest_entity_id: i32,
	newest_player_id: i32,
	players:          map[PlayerId]Player,
	entities:         map[EntityId]Entity,
}

EntityId :: distinct i32
PlayerId :: distinct i32
PlayerToken :: [16]u8

Player :: struct {
	player_id:   PlayerId,
	cursor_tile: [2]i32,
	token:       PlayerToken,
}
