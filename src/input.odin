package main

import "core:math"
import "fresnel"

InputActions :: enum i32 {
	MoveUp                     = 1,
	MoveDown                   = 2,
	MoveLeft                   = 3,
	MoveRight                  = 4,
	LeftClick                  = 5,
	RightClick                 = 6,
	ZoomIn                     = 101,
	ZoomOut                    = 102,
	DebugRenderHostStateToggle = 9000,
}

input_system :: proc(dt: f32) {
	player_entity, ok := &state.client.entities[state.client.controlling_entity_id]

	if ok {
		cmd := entity_get_command(player_entity)

		delta_pos: TileCoord = {0, 0}
		if is_action_just_pressed(.MoveRight) do delta_pos.x += 1
		if is_action_just_pressed(.MoveLeft) do delta_pos.x -= 1
		if is_action_just_pressed(.MoveUp) do delta_pos.y -= 1
		if is_action_just_pressed(.MoveDown) do delta_pos.y += 1

		if delta_pos != {0, 0} {
			if cmd.type == .None {
				cmd.pos = player_entity.pos
			}
			cmd.pos += delta_pos
			cmd.type = .Move
			cmd.target_entity = 0
			command_submit(cmd)
		}
	}

	if state.host.is_host && is_action_just_pressed(.DebugRenderHostStateToggle) {
		state.debug.render_host_state = !state.debug.render_host_state
	}

	if is_action_just_pressed(.ZoomIn) {
		state.client.zoom = math.min(8, state.client.zoom + 1)
	}
	if is_action_just_pressed(.ZoomOut) {
		state.client.zoom = math.max(1, state.client.zoom - 1)
	}

	if is_action_pressed(.LeftClick) {
		tile_draw(state.client.cursor_pos, .BrickWall)
	}
	if is_action_pressed(.RightClick) {
		tile_draw(state.client.cursor_pos, .Floor)
	}

}

is_action_pressed :: proc(action: InputActions) -> bool {
	return fresnel.is_action_pressed(i32(action))
}
is_action_just_pressed :: proc(action: InputActions) -> bool {
	return fresnel.is_action_just_pressed(i32(action))
}
