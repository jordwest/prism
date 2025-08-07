package main

import "prism"

AppState :: struct {
	t:              f32,
	width:          i32,
	height:         i32,
	client:         ClientState,
	host:           HostState,
	bytes_sent:     int,
	bytes_received: i32,
	debug:          DebugState,
}

// State common to both host and clients
CommonState :: struct {
	tiles:    Tiles,
	players:  map[PlayerId]Player,
	entities: map[EntityId]Entity,
	// TODO: Move player and entity map here
}

ClientState :: struct {
	common:                CommonState,
	cursor_pos:            TileCoord,
	cursor_screen_pos:     ScreenCoord,
	zoom:                  f32,
	camera:                prism.Spring(2),
	my_token:              PlayerToken,
	player_id:             PlayerId,
	controlling_entity_id: EntityId,

	// The sequence id of the command last issued by the client
	// See JOURNAL.md, 5 Aug 2025
	_cmd_seq:              i32,
}

HostState :: struct {
	common:           CommonState,
	is_host:          bool,
	newest_entity_id: i32,
	newest_player_id: i32,
	spawn_point:      TileCoord,
	clients:          map[i32]Client,
	pcg:              Maybe(^PcgState),

	// The sequence id of the event last fired by the server
	// See JOURNAL.md, 5 Aug 2025
	// evt_seq:          i32,
}

PlayerId :: distinct i32
PlayerToken :: [16]u8

Player :: struct {
	player_id:         PlayerId,
	player_entity_id:  EntityId,
	cursor_tile:       TileCoord,
	cursor_updated_at: f32,

	// Server only
	_token:            PlayerToken,

	// Client only
	_cursor_spring:    prism.Spring(2),
}

Client :: struct {
	player_id: PlayerId,
}

state_players :: proc(s: ^CommonState)

state_serialize :: proc(s: ^prism.Serializer, state: ^AppState) -> prism.SerializationResult {
	serialize(s, &state.t) or_return
	serialize(s, &state.client.my_token) or_return
	serialize(s, (^i32)(&state.client.player_id)) or_return

	return nil
}
