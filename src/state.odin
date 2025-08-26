package main

import "core:container/queue"
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
	////// Cursor state //////
	cursor_pos:             TileCoord,
	cursor_screen_pos:      ScreenCoord,
	cursor_hidden:          bool,
	cursor_last_moved:      f32,
	cursor_over_ui:         bool,

	////// Player feedback //////
	ui:                     UiState,
	audio:                  AudioState,
	fx:                     prism.Pool(Fx, 100),
	render:                 RenderState,

	////// Camera /////
	zoom:                   f32,
	camera:                 prism.Spring(2),
	controlling_entity_id:  EntityId,
	viewing_entity_id:      EntityId, // If non-zero, view this entity instead of the currently controlling entity

	//// Network state ////
	my_token:               PlayerToken,
	my_display_name:        prism.BufString(32),
	player_id:              PlayerId,
	join_mode:              JoinMode,
	connection_path:        prism.BufString(512),
	bytes_sent:             i32,
	bytes_received:         i32,

	///// Game state ////
	game:                   GameState,
	log_queue:              LogQueue,
	t_evaluate_turns_after: f32,
	log_entry_replay_state: LogEntryReplayState,
	// The sequence id of the command last issued by the client
	// See JOURNAL.md, 5 Aug 2025
	cmd_seq:                CmdSeqId,

	/////// Crash handling /////////
	crashed:                bool,
	frame_iter_count:       i32, // Used to crash out early instead of getting into infinite loops
}


LogEntryReplayState :: enum {
	AwaitingEntry, // We're ready to receive new events whenever they come in
	AwaitingAnimation, // Still processing the last event - but delayed to let an animation play
}

GameStatus :: enum {
	Lobby,
	Started,
	GameOver,
	GameWon,
}

// Game state (generally expected to be deterministic across clients)
GameState :: struct {
	seed:             u64,
	status:           GameStatus,
	spawn_point:      TileCoord,
	newest_entity_id: i32,
	newest_player_id: i32,
	current_turn:     i32,
	turn_complete:    bool, // All players have completed their turn and waiting for turn to advance
	tiles:            Tiles,
	items:            ItemTable,
	containers:       Containers,
	players:          map[PlayerId]Player,
	entities:         map[EntityId]Entity,
	derived:          DerivedState,
	pcg:              Maybe(^PcgState),
	next_log_seq:     LogSeqId,
	enemies_killed:   i32,
}

HostState :: struct {
	crashed:         bool,
	is_host:         bool,
	connection_path: string,
	last_turn_at:    f32,
	clients:         map[ClientId]Client,
	bytes_sent:      i32,
	bytes_received:  i32,
	game_log:        [dynamic]LogEntry,
	// True when the current completed turn has been sent off, to avoid double sends.
	// Resets at the beginning of another turn
	turn_sent_off:   bool,
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

state_check_for_infinite_loops :: proc() {
	state.client.frame_iter_count += 1
	if state.client.frame_iter_count > 100000 {
		state.client.crashed = true
		err("Iteration limit hit this frame, crashing")
		unreachable()
	}
}
