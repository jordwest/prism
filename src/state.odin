package main

import "prism"

SharedState :: struct {
	t:                  f32,
	width:              i32,
	height:             i32,
	other_pointer_down: u8,
	client:             ClientState,
	host:               HostState,
	bytes_sent:         int,
	bytes_received:     i32,
}


ClientState :: struct {
	cursor_pos:            TileCoord,
	zoom:                  f32,
	my_token:              PlayerToken,
	player_id:             PlayerId,
	controlling_entity_id: EntityId,
	players:               map[PlayerId]Player,
	entities:              map[EntityId]Entity,

	// The sequence id of the command last issued by the client
	// See JOURNAL.md, 5 Aug 2025
	cmd_seq:               i32,
}

HostState :: struct {
	is_host:          bool,
	newest_entity_id: i32,
	newest_player_id: i32,
	clients:          map[i32]Client,
	players:          map[PlayerId]Player,
	entities:         map[EntityId]Entity,

	// The sequence id of the event last fired by the server
	// See JOURNAL.md, 5 Aug 2025
	// evt_seq:          i32,
}

PlayerId :: distinct i32
PlayerToken :: [16]u8

Player :: struct {
	player_id:        PlayerId,
	player_entity_id: EntityId,
	cursor_tile:      TileCoord,

	// Server only
	_token:           PlayerToken,
}

Client :: struct {
	player_id: PlayerId,
}

serialize_state :: proc(s: ^prism.Serializer, state: ^SharedState) -> prism.SerializationResult {
	prism.serialize(s, &state.t) or_return
	prism.serialize(s, &state.client.my_token) or_return

	return nil
}
