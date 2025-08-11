package main

import "prism"

AppState :: struct {
	t:      f32,
	width:  i32,
	height: i32,
	client: ClientState,
	host:   HostState,
	debug:  DebugState,
}

ClientState :: struct {
	crashed:               bool,
	cursor_pos:            TileCoord,
	cursor_screen_pos:     ScreenCoord,
	cursor_hidden:         bool,
	zoom:                  f32,
	camera:                prism.Spring(2),
	my_token:              PlayerToken,
	player_id:             PlayerId,
	controlling_entity_id: EntityId,
	game:                  GameState,
	bytes_sent:            i32,
	bytes_received:        i32,
	audio_queue:           AudioQueue,

	// The sequence id of the command last issued by the client
	// See JOURNAL.md, 5 Aug 2025
	cmd_seq:               CmdSeqId,
}

// Game state (generally expected to be deterministic across clients)
GameState :: struct {
	spawn_point:      TileCoord,
	newest_entity_id: i32,
	newest_player_id: i32,
	current_turn:     i32,
	turn_complete:    bool, // All players have completed their turn and waiting for turn to advance
	tiles:            Tiles,
	players:          map[PlayerId]Player,
	entities:         map[EntityId]Entity,
	derived:          DerivedState,
	pcg:              Maybe(^PcgState),
	next_log_seq:     LogSeqId,
}

HostState :: struct {
	crashed:        bool,
	is_host:        bool,
	last_turn_at:   f32,
	clients:        map[ClientId]Client,
	bytes_sent:     i32,
	bytes_received: i32,
	game_log:       [dynamic]LogEntry,
}

ClientId :: distinct i32
PlayerId :: distinct i32
LogSeqId :: distinct i32

// A command sequence id is used by the client to track when local
// optimistic commands have been acknowledged by the server. It is
// unique per client and not kept in the log.
CmdSeqId :: distinct i32

PlayerToken :: [16]u8

log_seq_id_serialize :: proc(s: ^prism.Serializer, seq: ^LogSeqId) -> prism.SerializationResult {
	return prism.serialize_i32(s, (^i32)(seq))
}
cmd_seq_id_serialize :: proc(s: ^prism.Serializer, seq: ^CmdSeqId) -> prism.SerializationResult {
	return prism.serialize_i32(s, (^i32)(seq))
}
player_id_serialize :: proc(s: ^prism.Serializer, eid: ^PlayerId) -> prism.SerializationResult {
	return prism.serialize_i32(s, (^i32)(eid))
}

Player :: struct {
	player_id:         PlayerId,
	player_entity_id:  EntityId,

	// Not deterministic
	cursor_tile:       TileCoord,
	cursor_updated_at: f32,
	cursor_spring:     prism.Spring(2),
}

Client :: union {
	UnidentifiedClient,
	IdentifiedClient,
}

UnidentifiedClient :: struct {}
IdentifiedClient :: struct {
	player_id:   PlayerId,
	token:       PlayerToken,
	next_seq_id: LogSeqId,
}

state_serialize :: proc(s: ^prism.Serializer, state: ^AppState) -> prism.SerializationResult {
	serialize(s, &state.t) or_return
	serialize(s, &state.client.my_token) or_return
	serialize(s, &state.client.player_id) or_return

	return nil
}
