package main

import "core:math"
import "fresnel"

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
}

input_system :: proc(dt: f32) {
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
