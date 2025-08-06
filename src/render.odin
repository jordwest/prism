package main

import clay "clay-odin"
import "fresnel"
import "prism"

render_system :: proc(dt: f32) {
	render_move_camera(dt)
	render_tiles()
	render_entities()
	render_tile_cursors(dt)
	// render_ui()
}

// TODO: Does this really belong in render? Find a better home
render_move_camera :: proc(dt: f32) {
	if e, ok := state.client.entities[state.client.controlling_entity_id]; ok {
		target := vec2f(e.pos.xy)
		cmd := entity_get_command(&e)
		if cmd.type == .Move {
			target = target + ((vec2f(cmd.pos) - target) / 2)
		}
		state.client.camera.target = target
	}
	prism.spring_tick(&state.client.camera, dt)
}

render_tiles :: proc() {
	splitmix_state = SplitMixState{}
	t0 := fresnel.now()
	cull_margin := GRID_SIZE * state.client.zoom

	canvas_size := vec2f(state.width, state.height)


	for x: i32 = 0; x < 30; x += 1 {
		for y: i32 = 0; y < 20; y += 1 {
			tile := TileCoord{x, y}
			coord := screen_coord(tile)
			cull :=
				coord.x < -cull_margin ||
				coord.y < -cull_margin ||
				coord.x > (canvas_size.x + cull_margin) ||
				coord.y > (canvas_size.y + cull_margin)
			if cull do continue

			v := rand_float_at(u64(x), u64(y)) //rand_f32(hash_data[:])
			sprite := SPRITE_COORD_FLOOR_STONE
			if (v > 0.9) {
				sprite = SPRITE_COORD_FLOOR_STONE_2
			}
			if ((x == 5 || x == 12) && y == 3) {
				sprite = SPRITE_COORD_BRICK_WALL_BEHIND
			}
			if (x >= 5 && x <= 12 && y == 4) {
				sprite = SPRITE_COORD_BRICK_WALL_FACE
			}
			render_sprite(sprite, coord)
		}
	}

	t1 := fresnel.now()
	fresnel.metric_i32("Tile loop", t1 - t0)
}

render_sprite :: proc(sprite_coords: [2]f32, pos: ScreenCoord) {
	fresnel.draw_image(
		&fresnel.DrawImageArgs {
			image_id = 1,
			source_offset = sprite_coords,
			source_size = {SPRITE_SIZE, SPRITE_SIZE},
			dest_offset = pos.xy,
			dest_size = state.client.zoom * GRID_SIZE,
		},
	)
}

render_entities :: proc() {
	i: i32 = 0
	for id, &e in state.client.entities {
		i += 1
		meta := entity_meta[e.meta_id]

		coord := screen_coord(e.pos).xy
		if id, is_player := e.player_id.?; is_player {
			switch id {
			case 3:
				render_sprite(SPRITE_COORD_PLAYER_A, coord)
			case 2:
				render_sprite(SPRITE_COORD_PLAYER_B, coord)
			case 1:
				render_sprite(SPRITE_COORD_PLAYER_C, coord)
			case:
				render_sprite(meta.spritesheet_coord, coord)
			}

			if e.id == state.client.controlling_entity_id {
				render_sprite(
					SPRITE_COORD_ACTIVE_CHEVRON,
					screen_coord(tile_coord_f(e.pos) + TileCoordF({0, -0.5})),
				)
			} else {
				render_sprite(
					SPRITE_COORD_THOUGHT_BUBBLE,
					screen_coord(tile_coord_f(e.pos) + TileCoordF({0.75, -0.75})),
				)
			}
		} else {
			render_sprite(meta.spritesheet_coord, coord)
		}

		cmd := entity_get_command(&e)
		if cmd.type == .Move && .IsAllied in meta.flags {
			render_sprite(SPRITE_COORD_PLAYER_OUTLINE, screen_coord(cmd.pos))
		}
	}

	fresnel.metric_i32("entities rendered", i)
}

render_tile_cursors :: proc(dt: f32) {
	// Draw this player's cursor
	render_sprite(SPRITE_COORD_RECT, screen_coord(state.client.cursor_pos))

	// Draw other players' cursors
	for _, &p in state.client.players {
		if p.player_id != state.client.player_id {
			// Like render_move_camera, does this spring logic belong in a separate system (like an animation system)?
			p._cursor_spring.target = vec2f(p.cursor_tile)
			prism.spring_tick(&p._cursor_spring, dt)

			if p.cursor_updated_at == 0 || (state.t - p.cursor_updated_at > 3) {
				// Don't render stale cursors
				continue
			}

			cursor_pos := screen_coord(TileCoordF(p._cursor_spring.pos))
			text_pos := screen_coord(TileCoordF(p._cursor_spring.pos + {1, 0.75}))

			render_sprite(SPRITE_COORD_OTHER_PLAYER_CURSOR, cursor_pos)
			fresnel.fill(255, 255, 255, 1)
			fresnel.draw_text(text_pos.x, text_pos.y, 16, "Player")
		}
	}
}

render_ui :: proc() {
	render_commands := ui_layout_create()

	for i in 0 ..< i32(render_commands.length) {
		render_command := clay.RenderCommandArray_Get(&render_commands, i)

		#partial switch render_command.commandType {
		case .Rectangle:
			fresnel.fill(
				render_command.renderData.rectangle.backgroundColor.r,
				render_command.renderData.rectangle.backgroundColor.g,
				render_command.renderData.rectangle.backgroundColor.b,
				render_command.renderData.rectangle.backgroundColor.a / 255,
			)
			fresnel.draw_rect(
				render_command.boundingBox.x,
				render_command.boundingBox.y,
				render_command.boundingBox.width,
				render_command.boundingBox.height,
			)
		case .Text:
			c := render_command.renderData.text.textColor
			fresnel.fill(c.r, c.g, c.b, c.a)
			fresnel.draw_text(
				render_command.boundingBox.x,
				render_command.boundingBox.y,
				i32(render_command.renderData.text.fontSize),
				string_from_clay_slice(render_command.renderData.text.stringContents),
			)
		}
	}

}
