package main

import "core:math"
import "fresnel"

InputActions :: enum i32 {
	MoveUp                    = 1,
	MoveDown                  = 2,
	MoveLeft                  = 3,
	MoveRight                 = 4,
	LeftClick                 = 5,
	RightClick                = 6,
	Escape                    = 7,
	Skip                      = 8,
	ZoomIn                    = 101,
	ZoomOut                   = 102,
	DebugRenderOverlaysToggle = 9000,
}

input_system :: proc(dt: f32) {
	player_entity, ok := &state.client.game.entities[state.client.controlling_entity_id]

	if ok {
		cmd := entity_get_command(player_entity)

		delta_pos: TileCoord = {0, 0}
		if is_action_just_pressed(.MoveRight) do delta_pos.x += 1
		if is_action_just_pressed(.MoveLeft) do delta_pos.x -= 1
		if is_action_just_pressed(.MoveUp) do delta_pos.y -= 1
		if is_action_just_pressed(.MoveDown) do delta_pos.y += 1

		if delta_pos != {0, 0} {
			// Hide cursor when keys are pressed
			state.client.cursor_hidden = true

			if cmd.type != .Move {
				cmd.pos = player_entity.pos
			}
			cmd.pos += delta_pos
			cmd.type = .Move
			cmd.target_entity = 0
			command_submit(cmd)
		}
	}

	if is_action_just_pressed(.Escape) {
		command_submit(Command{})
	}
	if is_action_just_pressed(.Skip) {
		command_submit(Command{type = .Skip})
	}

	if is_action_just_pressed(.DebugRenderOverlaysToggle) {
		state.debug.render_debug_overlays = !state.debug.render_debug_overlays
	}

	if is_action_just_pressed(.ZoomIn) {
		state.client.zoom = math.min(8, state.client.zoom + 1)
	}
	if is_action_just_pressed(.ZoomOut) {
		state.client.zoom = math.max(1, state.client.zoom - 1)
	}

	if ok && is_action_just_pressed(.LeftClick) {
		cmd := game_command_for_tile(state.client.cursor_pos)
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
