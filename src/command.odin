package main

import "core:math/linalg"
import "prism"

CommandTypeId :: enum u8 {
	None,
	Skip,
	Move,
	Attack,
	Follow,
}

Command :: struct {
	type:          CommandTypeId,
	pos:           TileCoord,
	target_entity: EntityId,
}

CommandOutcome :: enum {
	// Executed command successfully, continue
	Ok,

	// Something went wrong when executing command, probably don't want to retry
	CommandFailed,

	// Has no action points, can't proceed
	NeedsActionPoints,

	// Has action points but no command
	NeedsInput,
}

// Execute current command for this entity as long as possible this turn
command_execute_all :: proc(entity: ^Entity) -> CommandOutcome {
	outcome: CommandOutcome = .Ok

	for outcome == .Ok {
		outcome = command_execute(entity)
	}

	return outcome
}

command_execute :: proc(entity: ^Entity) -> CommandOutcome {
	cmd := entity.cmd
	ap := entity.action_points
	if ap <= 0 do return .NeedsActionPoints

	trace("Execute command %v", cmd)

	// Have command and action points, try to move
	switch cmd.type {
	case .None:
		return .NeedsInput
	case .Move:
		return _move(entity)
	case .Attack:
		return _skip(entity) // TODO
	case .Follow:
		return _follow(entity)
	case .Skip:
		return _skip(entity)
	}

	return .Ok
}

_move :: proc(entity: ^Entity) -> CommandOutcome {
	dist_to_target := linalg.vector_length(vec2f(entity.cmd.pos - entity.pos))

	if dist_to_target == 0 {
		entity.cmd = Command{}
		return .Ok
	}

	if dist_to_target < 2 {
		entity.pos = entity.cmd.pos
		entity.action_points -= 100
		state_clear_djikstra_maps()
		// Reached destination
		entity.cmd = Command{}
		return .Ok
	}

	dmap, e := entity_djikstra_map_to(entity.id)
	if e != nil {
		entity.cmd = Command{}
		err("No path to target")
		return .CommandFailed
	}

	// Find path to player from target
	path_len := prism.djikstra_path(dmap, tmp_path[:], Vec2i(entity.cmd.pos))
	if path_len == 0 {
		entity.cmd = Command{}
		err("Path len 0")
		return .CommandFailed
	}

	next_step := TileCoord(tmp_path[path_len - 1])
	entity.pos = next_step
	entity.action_points -= 100
	state_clear_djikstra_maps()

	if next_step == entity.cmd.pos {
		// Reached destination
		entity.cmd = Command{}
	}
	return .Ok
}

_follow :: proc(entity: ^Entity) -> CommandOutcome {
	target, ok := state.client.game.entities[entity.cmd.target_entity]
	if !ok {
		entity.cmd = Command{}
		return .CommandFailed
	}

	switch _move_towards(entity, target.pos) {
	case .Moved:
		return .Ok
	case .MovedAndReachedTarget:
		return .Ok
	case .NoPathToTarget:
		entity.cmd = Command{}
		return .CommandFailed
	case .AlreadyAtTarget:
		return _skip(entity) // Skip turns until followed player moves away
	}
	return .Ok
}

_skip :: proc(entity: ^Entity) -> CommandOutcome {
	entity.action_points -= 100
	entity.cmd = Command{}
	return .Ok
}

@(private = "file")
MoveOutcome :: enum {
	Moved,
	MovedAndReachedTarget,
	NoPathToTarget,
	AlreadyAtTarget,
}

@(private = "file")
_move_towards :: proc(entity: ^Entity, destination: TileCoord) -> MoveOutcome {
	dist_to_target := linalg.vector_length(vec2f(destination - entity.pos))

	if dist_to_target == 0 {
		entity.cmd = Command{}
		return .AlreadyAtTarget
	}

	if dist_to_target < 2 {
		entity.pos = destination
		entity.action_points -= 100
		state_clear_djikstra_maps()
		return .MovedAndReachedTarget
	}

	dmap, e := entity_djikstra_map_to(entity.id)
	if e != nil {
		entity.cmd = Command{}
		err("No path to target")
		return .NoPathToTarget
	}

	// Find path to player from target
	path_len := prism.djikstra_path(dmap, tmp_path[:], Vec2i(destination))
	if path_len == 0 {
		entity.cmd = Command{}
		err("Path len 0")
		return .NoPathToTarget
	}

	next_step := TileCoord(tmp_path[path_len - 1])
	entity.pos = next_step
	entity.action_points -= 100
	state_clear_djikstra_maps()

	return next_step == destination ? .MovedAndReachedTarget : .Moved
}

command_serialize :: proc(s: ^prism.Serializer, cmd: ^Command) -> prism.SerializationResult {
	prism.serialize(s, (^u8)(&cmd.type)) or_return
	prism.serialize(s, (^[2]i32)(&cmd.pos)) or_return
	prism.serialize(s, (^i32)(&cmd.target_entity)) or_return
	return nil
}

// Client-side command submission
command_submit :: proc(cmd: Command) {
	state.client.cmd_seq += 1
	if entity, ok := &state.client.game.entities[state.client.controlling_entity_id]; ok {
		entity._local_cmd = LocalCommand {
			cmd     = cmd,
			cmd_seq = state.client.cmd_seq,
			t       = state.t,
		}
		client_send_message(
			ClientMessageSubmitCommand {
				entity_id = state.client.controlling_entity_id,
				cmd = cmd,
				cmd_seq = state.client.cmd_seq,
			},
		)
	}
}
