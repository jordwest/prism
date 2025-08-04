package main

ClientState :: struct {
	t:                  f32,
	test:               u8,
	greeting:           string,
	width:              i32,
	height:             i32,
	other_pointer_down: u8,
	cursor_pos:         [2]i32,
	players:            PlayerList,
	my_token:           PlayerToken
}

HostState :: struct {
    is_host: bool,
    players: PlayerList,
}

PlayerId :: distinct i32
PlayerToken :: [16]u8

PlayerMeta :: struct {
	player_id:   PlayerId,
	cursor_tile: [2]i32,
	token:       PlayerToken
}

PlayerList :: map[PlayerId]PlayerMeta
