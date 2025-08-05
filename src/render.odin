package main

import clay "clay-odin"
import "fresnel"

render_tiles :: proc() {
	grid_size := 16
	scale := 2
	view_grid := grid_size * scale

	splitmix_state = SplitMixState{}
	t0 := fresnel.now()
	hash_data: [10]u8 = {34, 54, 77, 124, 12, 45, 0, 221, 123, 139}
	for x := 0; x < 30; x += 1 {
		for y := 0; y < 20; y += 1 {
			hash_data[0] = u8(y)
			hash_data[1] = u8(x)
			hash_data[2] = u8(state.t)
			v := rand_float_at(u64(x), u64(y)) //rand_f32(hash_data[:])
			sx := 2
			if (v > 0.9) {
				sx = 3
			}
			// text := fmt.tprintf("%.1f", v)
			fresnel.draw_image(
				&fresnel.DrawImageArgs {
					image_id = 1,
					source_offset = {f32(sx * 16), 3 * 16},
					source_size = {16, 16},
					dest_offset = {f32(x * view_grid), f32(y * view_grid)},
					dest_size = {f32(view_grid), f32(view_grid)},
				},
			)
			// fresnel.fill(255, 255, 255, 255)
			// fresnel.draw_text(f32(x * view_grid), f32(y * view_grid), 16, text)
		}
	}
	t1 := fresnel.now()
	fresnel.metric_i32("Tile loop", t1 - t0)
}

render_entities :: proc() {
	i: i32 = 0
	for id, e in state.client.entities {
		i += 1
		meta := entity_meta[e.meta_id]
		offset := e.pos * 32
		fresnel.draw_image(
			&fresnel.DrawImageArgs {
				image_id = 1,
				source_offset = meta.spritesheet_coord,
				source_size = {16, 16},
				dest_offset = {f32(offset.x), f32(offset.y)},
				dest_size = {32, 32},
			},
		)
	}

	fresnel.metric_i32("entities rendered", i)
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

	// Draw this player's cursor
	cursor_pos := vec2f(state.client.cursor_pos) * 32

	fresnel.draw_image(
		&fresnel.DrawImageArgs {
			image_id = 1,
			source_offset = SPRITE_COORD_RECT,
			source_size = {16, 16},
			dest_offset = cursor_pos,
			dest_size = {32, 32},
		},
	)

	// Draw other players' cursors
	for _, p in state.client.players {
		if p.player_id != state.client.player_id {
			cursor_pos := vec2f(p.cursor_tile) * 32

			zoom: i32 = 2
			fresnel.draw_image(
				&fresnel.DrawImageArgs {
					image_id = 1,
					source_offset = SPRITE_COORD_OTHER_PLAYER_CURSOR,
					source_size = {16, 16},
					dest_offset = cursor_pos - {3, 3} + vec2f(8 * zoom),
					dest_size = {32, 32},
				},
			)
			fresnel.fill(255, 255, 255, 1)
			fresnel.draw_text(cursor_pos.x, cursor_pos.y, 16, "Player")
		}
	}

}
