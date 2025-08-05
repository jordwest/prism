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
	for x: i32 = 0; x < 30; x += 1 {
		for y: i32 = 0; y < 20; y += 1 {
			tile := TileCoord{x, y}
			v := rand_float_at(u64(x), u64(y)) //rand_f32(hash_data[:])
			sx := 2
			if (v > 0.9) {
				sx = 3
			}
			fresnel.draw_image(
				&fresnel.DrawImageArgs {
					image_id = 1,
					source_offset = {f32(sx * 16), 3 * 16},
					source_size = {SPRITE_SIZE, SPRITE_SIZE},
					dest_offset = screen_coord(tile).xy,
					dest_size = state.client.zoom * GRID_SIZE,
				},
			)
		}
	}
	t1 := fresnel.now()
	fresnel.metric_i32("Tile loop", t1 - t0)
}

render_entities :: proc() {
	i: i32 = 0
	for id, &e in state.client.entities {
		i += 1
		meta := entity_meta[e.meta_id]
		fresnel.draw_image(
			&fresnel.DrawImageArgs {
				image_id = 1,
				source_offset = meta.spritesheet_coord,
				source_size = {SPRITE_SIZE, SPRITE_SIZE},
				dest_offset = screen_coord(e.pos).xy,
				dest_size = state.client.zoom * GRID_SIZE,
			},
		)

		cmd := entity_get_command(&e)
		if cmd.type == .Move && .IsAllied in meta.flags {
			fresnel.draw_image(
				&fresnel.DrawImageArgs {
					image_id = 1,
					source_offset = SPRITE_COORD_PLAYER_OUTLINE,
					source_size = {SPRITE_SIZE, SPRITE_SIZE},
					dest_offset = screen_coord(cmd.pos).xy,
					dest_size = state.client.zoom * GRID_SIZE,
				},
			)
		}
	}

	fresnel.metric_i32("entities rendered", i)
}

render_tile_cursors :: proc(dt: f32) {
	// Draw this player's cursor
	fresnel.draw_image(
		&fresnel.DrawImageArgs {
			image_id = 1,
			source_offset = SPRITE_COORD_RECT,
			source_size = {SPRITE_SIZE, SPRITE_SIZE},
			dest_offset = screen_coord(state.client.cursor_pos).xy,
			dest_size = state.client.zoom * GRID_SIZE,
		},
	)
	// trace("Cursor at %v", screen_coord(state.client.cursor_pos).xy)

	// Draw other players' cursors
	for _, &p in state.client.players {
		if p.player_id != state.client.player_id {
			// Like render_move_camera, does this spring logic belong in a separate system (like an animation system)?
			p._cursor_spring.target = vec2f(p.cursor_tile)
			prism.spring_tick(&p._cursor_spring, dt)

			cursor_pos := screen_coord(TileCoordF(p._cursor_spring.pos - 0.5))

			zoom: i32 = 2
			fresnel.draw_image(
				&fresnel.DrawImageArgs {
					image_id = 1,
					source_offset = SPRITE_COORD_OTHER_PLAYER_CURSOR,
					source_size = {SPRITE_SIZE, SPRITE_SIZE},
					dest_offset = (cursor_pos - {3, 3} + (state.client.zoom * GRID_SIZE)).xy,
					dest_size = state.client.zoom * GRID_SIZE,
				},
			)
			fresnel.fill(255, 255, 255, 1)
			fresnel.draw_text(cursor_pos.x, cursor_pos.y, 16, "Player")
		}
	}
}

render_ui :: proc() {
	render_commands := ui_layout_create()

	for i in 0 ..< i32(render_commands.length) {
		render_command := clay.RenderCommandArray_Get(&render_commands, i)

		#partial switch render_command.commandType {
		case .Rectangle:
			// if render_command.renderData.rectangle.backgroundColor.a != 1 {
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
