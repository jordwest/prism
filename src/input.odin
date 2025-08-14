package main

import "core:math"
import "fresnel"
import "prism"

InputActions :: enum i32 {
	MoveUp                    = 1,
	MoveDown                  = 2,
	MoveLeft                  = 3,
	MoveRight                 = 4,
	MoveNE                    = 5,
	MoveSE                    = 6,
	MoveSW                    = 7,
	MoveNW                    = 8,
	LeftClick                 = 20,
	RightClick                = 21,
	Escape                    = 22,
	Skip                      = 23,
	ZoomIn                    = 101,
	ZoomOut                   = 102,
	DebugRenderOverlaysToggle = 9000,
	DebugNextView             = 9001,
	TempGameStart             = 9002,
	DebugHostReplay           = 9003,
}

_replay_storage: [1048576]u8
input_frame :: proc(dt: f32) {
	if state.debug.turn_stepping != .Off {
		if is_action_just_pressed(.Skip) {
			if log_queue_can_pop(&state.client.log_queue) do state.debug.turn_stepping = .Step
			return // Ignore all other input this frame to avoid player wait firing
		}
	}

	if is_action_just_pressed(.DebugHostReplay) && state.host.is_host {
		if len(state.host.game_log) <= 1 {
			// Load replay
			bytes := fresnel.storage_get("replay", _replay_storage[:])
			if bytes == 0 do return
			count: i32 = 0
			ser := prism.create_deserializer(_replay_storage[:])
			entry: LogEntry
			result := serialize(&ser, &count)
			game_reset()
			clear(&state.client.game.players)
			for i: i32 = 0; i < count; i += 1 {
				result := serialize(&ser, &entry)
				trace("Deserialization Result %v - %v", result, entry)
				log_queue_push(&state.client.log_queue, entry)
			}
			state.host.is_host = false
		} else {
			ser := prism.create_serializer(_replay_storage[:])
			count := i32(len(state.host.game_log))
			serialize(&ser, &count)
			for &log in &state.host.game_log {
				result := serialize(&ser, &log)
				trace("Serialization Result %v", result)
			}
			fresnel.storage_set("replay", _replay_storage[:ser.offset])
		}
		// Temporary hack to make this replaying work, since the host will otherwise
		// submit a bunch of turn end events to the log
		trace("%v", state.host.game_log)
	}

	player_entity, ok := player_entity().?

	if ok {
		cmd := entity_get_command(player_entity)

		delta_pos: TileCoord = {0, 0}
		if is_action_just_pressed(.MoveRight) do delta_pos.x += 1
		if is_action_just_pressed(.MoveLeft) do delta_pos.x -= 1
		if is_action_just_pressed(.MoveUp) do delta_pos.y -= 1
		if is_action_just_pressed(.MoveDown) do delta_pos.y += 1

		if is_action_just_pressed(.MoveNE) do delta_pos += {1, -1}
		if is_action_just_pressed(.MoveSE) do delta_pos += {1, 1}
		if is_action_just_pressed(.MoveSW) do delta_pos += {-1, 1}
		if is_action_just_pressed(.MoveNW) do delta_pos += {-1, -1}

		if delta_pos != {0, 0} {
			// Hide cursor when keys are pressed
			state.client.cursor_hidden = true

			previous_pos := player_entity.pos
			if cmd.type == .Move {
				previous_pos = cmd.pos
			}
			if cmd.type == .Attack {
				target, ok := entity(cmd.target_entity).?
				if ok do previous_pos = target.pos
			}

			new_cmd := command_for_tile(previous_pos + delta_pos)
			if new_cmd.type != .None do command_submit(new_cmd)
		}

		if is_action_just_pressed(.Skip) && player_entity.action_points > 0 {
			command_submit(Command{type = .Skip})
		}
	}

	if is_action_just_pressed(.Escape) {
		command_submit(Command{})
	}

	if is_action_just_pressed(.DebugRenderOverlaysToggle) {
		state.debug.render_debug_overlays = !state.debug.render_debug_overlays
	}
	if is_action_just_pressed(.DebugNextView) do debug_next_view()

	if is_action_just_pressed(.ZoomIn) {
		state.client.zoom = math.min(8, state.client.zoom + 1)
	}
	if is_action_just_pressed(.ZoomOut) {
		state.client.zoom = math.max(1, state.client.zoom - 1)
	}

	if ok && is_action_just_pressed(.LeftClick) {
		cmd := command_for_tile(state.client.cursor_pos)
		if cmd.type == .None do return

		command_submit(cmd)
		state.client.cursor_hidden = true
	}

	if is_action_just_pressed(.TempGameStart) && state.host.is_host {
		host_log_entry(LogEntryGameStarted{})
	}

	// TODO Cheat commands later?
	// if is_action_pressed(.LeftClick) {
	// 	tile_draw(state.client.cursor_pos, .BrickWall)
	// 	state_clear_djikstra_maps()
	// }
	// if is_action_pressed(.RightClick) {
	// 	tile_draw(state.client.cursor_pos, .Floor)
	// 	state_clear_djikstra_maps()
	// }

}

is_action_pressed :: proc(action: InputActions) -> bool {
	return fresnel.is_action_pressed(i32(action))
}
is_action_just_pressed :: proc(action: InputActions) -> bool {
	return fresnel.is_action_just_pressed(i32(action))
}
