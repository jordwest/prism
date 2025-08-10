package main

import "core:math/linalg"
import "prism"

CommandTypeId :: enum u8 {
	None,
	Skip,
	Move,
	Attack,
	// Follow,
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
	// case .Follow:
	// 	return _follow(entity)
	case .Skip:
		return _skip(entity)
	}

	return .Ok
}

_move :: proc(entity: ^Entity) -> CommandOutcome {
	outcome, at_target := _player_move_towards(entity, entity.cmd.pos, allow_swap = true)
	switch outcome {
	case .Moved:
		if at_target do entity_clear_cmd(entity)
		return .Ok
	case .Blocked:
		entity_clear_cmd(entity)
		return .CommandFailed
	case .AlreadyAtTarget:
		entity_clear_cmd(entity)
		return .Ok
	}
	return .Ok
}

// _follow :: proc(entity: ^Entity) -> CommandOutcome {
// 	target, ok := state.client.game.entities[entity.cmd.target_entity]
// 	if !ok {
// 		entity_clear_cmd(entity)
// 		return .CommandFailed
// 	}

// 	switch _player_move_towards(entity, target.pos) {
// 	case .Moved:
// 		return .Ok
// 	case .MovedAndSwappedWithTarget:
// 		err("Follow should not swap with target")
// 		return .Ok
// 	case .MovedAndReachedTarget:
// 		return .Ok
// 	case .NoPathToTarget:
// 		entity_clear_cmd(entity)
// 		return .CommandFailed
// 	case .TargetBlocked:
// 		return _skip(entity) // Skip turns until followed player moves away
// 	case .AlreadyAtTarget:
// 		return _skip(entity) // Skip turns until followed player moves away
// 	}
// 	return .Ok
// }

_skip :: proc(entity: ^Entity) -> CommandOutcome {
	entity.action_points -= 100
	entity.cmd = Command{}
	return .Ok
}

@(private = "file")
MoveOutcome :: enum {
	Moved,
	Blocked,
	AlreadyAtTarget,
}

@(private = "file")
_player_move_towards :: proc(
	entity: ^Entity,
	destination: TileCoord,
	allow_swap := false,
) -> (
	outcome: MoveOutcome,
	reached_target: bool,
) {
	dist_to_target := linalg.vector_length(vec2f(destination - entity.pos))

	if dist_to_target == 0 {
		entity_clear_cmd(entity)
		return .AlreadyAtTarget, true
	}

	if dist_to_target < 2 {
		outcome = _move_or_swap(entity, destination, allow_swap)
		if outcome == .Blocked do return .Blocked, false
		return outcome, true
	}

	dmap, e := derived_djikstra_map_to(entity.id)
	if e != nil {
		entity_clear_cmd(entity)
		err("No path to target")
		return .Blocked, false
	}

	// Find path to player from target
	path_len := prism.djikstra_path(dmap, tmp_path[:], Vec2i(destination))
	if path_len == 0 {
		entity_clear_cmd(entity)
		err("Path len 0")
		return .Blocked, false
	}

	next_step := TileCoord(tmp_path[path_len - 1])
	return _move_or_swap(entity, next_step, allow_swap), next_step == destination
}

_move_or_swap :: proc(entity: ^Entity, pos: TileCoord, allow_swap: bool = true) -> MoveOutcome {
	// Check if there's something in the way
	entities := derived_entities_at(pos)
	if obstacle, has_obstacle := entities.obstacle.?; has_obstacle {
		if allow_swap && .CanSwapPlaces in obstacle.flags {
			entity_swap_pos(entity, obstacle)
			return .Moved
		}
		return .Blocked
	}

	entity_set_pos(entity, pos)
	entity_consume_ap(entity, 100)
	return .Moved
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
