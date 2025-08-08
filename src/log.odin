package main

import "prism"

///////////////////// UNION ////////////////////

LogEntry :: union {
	LogEntryPlayerJoined,
	LogEntryCommand,
}

log_replay_entry :: proc(entry: LogEntry) -> Error {
	switch e in entry {
	case LogEntryPlayerJoined:
		_on_player_joined(e) or_return
	case LogEntryCommand:
		_on_command(e) or_return
	}

	return nil
}

///////////////////// VARIANTS ////////////////////

LogEntryPlayerJoined :: struct {
	player_id: PlayerId,
}

LogEntryCommand :: struct {
	player_id: PlayerId,
	entity_id: EntityId,
	cmd:       Command,
}

////////////////// HANDLERS ///////////////////////

@(private = "file")
_on_player_joined :: proc(entry: LogEntryPlayerJoined) -> Error {
	s := &state.client.game
	s.players[entry.player_id] = Player {
		player_id     = entry.player_id,
		cursor_spring = prism.spring_create(2, [2]f32{0, 0}, k = 40, c = 10),
	}

	// Create an entity
	player_entity := game_spawn_entity({meta_id = .Player})
	player_entity.player_id = entry.player_id
	spawn, ok := game_find_nearest_traversable_space(state.client.game.spawn_point)
	if !ok do return error(NoSpaceForEntity{entity_id = player_entity.id, pos = state.client.game.spawn_point})
	player_entity.pos = spawn

	if state.client.player_id == entry.player_id {
		state.client.controlling_entity_id = player_entity.id
	}

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

///////////////////// SERIALIZATION ////////////////////

@(private = "file")
S :: prism.Serializer
@(private = "file")
SResult :: prism.SerializationResult

log_entry_serialize :: proc(s: ^S, entry: ^LogEntry) -> SResult {
	state := prism.serialize_union_create(s, entry)
	prism.serialize_union_nil(0, &state)
	prism.serialize_union_variant(1, LogEntryPlayerJoined, _serialize_variant, &state) or_return
	prism.serialize_union_variant(4, LogEntryCommand, _serialize_variant, &state) or_return
	return prism.serialize_union_fail_if_not_found(&state)
}

_serialize_variant :: proc {
	_player_joined_serialize,
	_command_serialize,
}

_player_joined_serialize :: proc(s: ^S, entry: ^LogEntryPlayerJoined) -> SResult {
	serialize(s, &entry.player_id)
	return nil
}

_command_serialize :: proc(s: ^S, entry: ^LogEntryCommand) -> SResult {
	serialize(s, &entry.player_id) or_return
	serialize(s, &entry.entity_id) or_return
	serialize(s, &entry.cmd) or_return
	return nil
}
