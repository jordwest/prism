package main

ClientState :: struct {
	t:                  f32,
	test:               u8,
	greeting:           string,
	width:              i32,
	height:             i32,
	other_pointer_down: u8,
	cursor_pos:         [2]i32,
	player_id:          PlayerId,
	players:            PlayerList,
	my_token:           PlayerToken,
	entities:           map[EntityId]Entity,
}

HostState :: struct {
	is_host:          bool,
	newest_entity_id: i32,
	newest_player_id: i32,
	players:          PlayerList,
}

EntityId :: distinct i32
PlayerId :: distinct i32
PlayerToken :: [16]u8

Player :: struct {
	player_id:   PlayerId,
	cursor_tile: [2]i32,
	token:       PlayerToken,
}

PlayerList :: map[PlayerId]Player
