package main

import "core:container/queue"
import "fresnel"
import "prism"

///////////////////// UNION ////////////////////

LogEntry :: union {
	LogEntryPlayerJoined,
	LogEntryGameStarted,
	LogEntryCommand,
	LogEntryAdvanceTurn,
}

log_replay_entry :: proc(entry: LogEntry) -> Error {
	if LOG_LOG_ENTRIES do info("log_replay_entry: %v", entry)
	switch e in entry {
	case LogEntryPlayerJoined:
		_on_player_joined(e) or_return
	case LogEntryGameStarted:
		_on_game_started(e) or_return
	case LogEntryCommand:
		_on_command(e) or_return
	case LogEntryAdvanceTurn:
		_on_advance_turn(e) or_return
	}

	return nil
}
///////////////////// VARIANTS ////////////////////

LogEntryPlayerJoined :: struct {
	player_id:    PlayerId,
	display_name: prism.BufString(32),
}

LogEntryGameStarted :: struct {
	game_seed: u64,
}

LogEntryAdvanceTurn :: struct {}

LogEntryCommand :: struct {
	player_id: PlayerId,
	entity_id: EntityId,
	cmd:       Command,
}

////////////////// HANDLERS ///////////////////////

@(private = "file")
_on_game_started :: proc(entry: LogEntryGameStarted) -> Error {
	pcg, ok := state.client.game.pcg.?
	if !ok do return error(InvariantError{})

	if state.client.game.status == .Started do return error(ErrorCode.GameAlreadyStarted)

	if state.client.game.status == .GameOver || state.client.game.status == .GameWon do game_reset()

	info("Starting game with seed 0x%x", entry.game_seed)
	state.client.game.seed = entry.game_seed

	when DEBUG_TEST_ROOM_ENABLED {
		debug_generate_test_room()
	} else {
		t0 := fresnel.now()
		for !pcg.done {
			procgen_iterate(pcg)
		}
		t1 := fresnel.now()
		pcg.total_time += (t1 - t0)
	}

	fresnel.metric_i32("djikstra_iterations", pcg.djikstra_map.iterations)

	player_count := i32(len(state.client.game.players))
	// Spawn all players
	for player_id, &player in &state.client.game.players {
		spawn, ok := game_find_nearest_traversable_space(state.client.game.spawn_point)
		player_entity := game_spawn_entity(.Player, {player_id = player_id, pos = spawn})
		if !ok do return error(NoSpaceForEntity{entity_id = player_entity.id, pos = state.client.game.spawn_point})

		player.player_entity_id = player_entity.id

		if state.client.player_id == player_id {
			state.client.controlling_entity_id = player_entity.id
		}
	}

	item_spawn(
		ItemStack {
			container_id = SharedLootContainer,
			count = player_count,
			type = PotionType.Healing,
		},
		in_batch = true,
	)
	containers_reset()

	fresnel.cursor_hide()
	state.client.game.status = .Started
	vision_update()

	return nil
}

@(private = "file")
_on_player_joined :: proc(entry: LogEntryPlayerJoined) -> Error {
	s := &state.client.game

	s.players[entry.player_id] = Player {
		player_id     = entry.player_id,
		display_name  = entry.display_name,
		// player_entity_id = assigned in _on_game_started,
		cursor_spring = prism.spring_create(2, [2]f32{0, 0}, k = 40, c = 10),
	}

	vision_update()

	return nil
}
@(private = "file")
_on_advance_turn :: proc(entry: LogEntryAdvanceTurn) -> Error {
	event_fire(EventTurnEnding{}) or_return
	event_fire(EventTurnStarting{}) or_return
	return nil
}

@(private = "file")
_on_command :: proc(entry: LogEntryCommand) -> Error {
	s := &state.client.game
	entity, ok := &s.entities[entry.entity_id]
	if !ok do return error(EntityNotFound{entity_id = entry.entity_id})
	if entity.player_id != entry.player_id {
		return error(
			PlayerCommandWrongEntity {
				entity_id = entity.id,
				entity_player_id = entity.player_id,
				cmd_player_id = entry.player_id,
			},
		)
	}

	entity.cmd = entry.cmd

	if p, is_player := &s.players[entity.player_id.? or_else 0]; is_player {
		// Mark their cursor as stale to hide it immediately
		p.cursor_updated_at = 0
	}
	return nil
}

////////////////// QUEUE ////////////////////

LogQueue :: struct {
	_queue:   queue.Queue(LogEntry),
	_backing: [256]LogEntry,
	i:        int,
}

log_queue_init :: proc(lq: ^LogQueue) {
	queue.init_from_slice(&lq._queue, lq._backing[:])
}

log_queue_can_push :: proc(lq: ^LogQueue) -> bool {
	return queue.len(lq._queue) < queue.cap(lq._queue)
}

log_queue_can_pop :: proc(lq: ^LogQueue) -> bool {
	return queue.len(lq._queue) > 0
}

log_queue_push :: proc(lq: ^LogQueue, log_entry: LogEntry) {
	queue.push_back(&lq._queue, log_entry)
}

log_queue_iterate :: proc(lq: ^LogQueue) -> (LogEntry, int, bool) {
	elem, ok := queue.pop_front_safe(&lq._queue)
	if !ok do return nil, lq.i, false
	defer lq.i += 1
	return elem, lq.i, true
}

log_frame :: proc() -> Error {
	if state.debug.turn_stepping == .Paused do return nil

	switch state.client.log_entry_replay_state {
	case .AwaitingEntry:
		// Pick the next log entry off the queue or return
		entry, _, ok := log_queue_iterate(&state.client.log_queue)
		if entry == nil do return nil
		log_replay_entry(entry) or_return
	case .AwaitingAnimation:
		if state.t < state.client.t_evaluate_turns_after do return nil // Still waiting
		state.client.log_entry_replay_state = .AwaitingEntry
	}

	if state.client.game.status == .Started {
		turn_evaluate() or_return
		derived_ensure_fov()
	}

	if state.debug.turn_stepping == .Step {
		state.debug.turn_stepping = .Paused
		return nil
	}
	return nil
}

///////////////////// SERIALIZATION ////////////////////

@(private = "file")
S :: prism.Serializer
@(private = "file")
SResult :: prism.SerializationResult

log_entry_serialize :: proc(s: ^S, entry: ^LogEntry) -> SResult {
	state := prism.serialize_union_create(s, entry)
	prism.serialize_union_nil(0, &state)
	prism.serialize_union_variant(1, LogEntryPlayerJoined, _serialize_variant, &state) or_return
	prism.serialize_union_variant(2, LogEntryGameStarted, _serialize_variant, &state) or_return
	prism.serialize_union_variant(3, LogEntryAdvanceTurn, prism.serialize_empty, &state) or_return
	prism.serialize_union_variant(4, LogEntryCommand, _serialize_variant, &state) or_return
	return prism.serialize_union_fail_if_not_found(&state)
}

_serialize_variant :: proc {
	_game_started_serialize,
	_player_joined_serialize,
	_command_serialize,
}
_game_started_serialize :: proc(s: ^S, entry: ^LogEntryGameStarted) -> SResult {
	serialize(s, &entry.game_seed)
	return nil
}

_player_joined_serialize :: proc(s: ^S, entry: ^LogEntryPlayerJoined) -> SResult {
	serialize(s, &entry.player_id)
	serialize(s, &entry.display_name)
	return nil
}

_command_serialize :: proc(s: ^S, entry: ^LogEntryCommand) -> SResult {
	serialize(s, &entry.player_id) or_return
	serialize(s, &entry.entity_id) or_return
	serialize(s, &entry.cmd) or_return
	return nil
}
