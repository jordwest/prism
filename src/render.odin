package main

import clay "clay-odin"
import "core:fmt"
import "core:math"
import "fresnel"
import "prism"

@(private = "file")
_tempstr_buf: [16384]u8

render_system :: proc(dt: f32) {
	render_move_camera(dt)
	render_tiles()
	render_entities(dt)
	render_tile_cursors(dt)
	render_fx(dt)
	if !state.client.cursor_hidden && command_for_tile(state.client.cursor_pos).type == .Move {
		render_path_to(state.client.cursor_pos, alpha = 80)
	}
	// render_ui()
	if state.debug.render_debug_overlays {
		render_debug_overlays()
	}
}

@(private = "file")
_debug_y_offset: f32 = 16

@(private = "file")
_add_debug_text :: proc(fmt_str: string, args: ..any) {
	fresnel.draw_text_fmt(16, _debug_y_offset, 16, fmt_str, ..args)
	_debug_y_offset += 16
}

render_debug_overlays :: proc() {
	fresnel.fill(255, 255, 255, 255)
	_debug_y_offset = 16
	_add_debug_text("Debug overlays: %v", state.debug.view)
	_add_debug_text("Turn %d, t=%.2f", state.client.game.current_turn, state.t)
	_add_debug_text("%.0f FPS (%.0f max, %.0f min)", debug_get_fps())

	if pcg, ok := state.client.game.pcg.?; ok {
		if !pcg.done {
			offset := screen_coord(TileCoord({pcg.cursor.x1, pcg.cursor.y1}))
			dims := vec2f(prism.aabb_size(pcg.cursor)) * GRID_SIZE * state.client.zoom
			fresnel.fill(255, 200, 200, 0.5)
			fresnel.draw_rect(offset.x, offset.y, dims.x, dims.y)

			offset = screen_coord(TileCoord({pcg.cursor2.x1, pcg.cursor2.y1}))
			dims = vec2f(prism.aabb_size(pcg.cursor2)) * GRID_SIZE * state.client.zoom
			fresnel.fill(170, 170, 255, 0.5)
			fresnel.draw_rect(offset.x, offset.y, dims.x, dims.y)
		}
	}

	switch state.debug.view {
	case .None:
	case .CurrentPlayerDjikstra:
		dmap, e := derived_djikstra_map_to(state.client.controlling_entity_id)
		_visualise_djikstra(dmap)
	case .AllPlayersDjikstra:
		dmap, e := derived_allies_djikstra_map()
		_visualise_djikstra(dmap)
	}

	// Render cursor coords
	fresnel.fill(255, 255, 255, 255)
	cursor_text := fmt.bprintf(
		_tempstr_buf[:],
		"(%d, %d)",
		state.client.cursor_pos.x,
		state.client.cursor_pos.y,
	)
	cursor_screen := state.client.cursor_screen_pos + ScreenCoord{32, 32}
	fresnel.draw_text(cursor_screen.x, cursor_screen.y, 16, cursor_text)

	entities_at_cursor := derived_entities_at(state.client.cursor_pos, ignore_out_of_bounds = true)
	if obstacle, has_obstacle := entities_at_cursor.obstacle.?; has_obstacle {
		fresnel.fill(255, 255, 255, 1)
		fresnel.draw_text_fmt(cursor_screen.x, cursor_screen.y + 16, 16, "ID %d", obstacle.id)
		fresnel.draw_text_fmt(
			cursor_screen.x,
			cursor_screen.y + 32,
			16,
			"%d AP",
			obstacle.action_points,
		)
		fresnel.draw_text_fmt(cursor_screen.x, cursor_screen.y + 48, 16, "%v", obstacle.cmd)
		fresnel.draw_text_fmt(cursor_screen.x, cursor_screen.y + 64, 16, "%v", obstacle.meta.flags)
		fresnel.draw_text_fmt(
			cursor_screen.x,
			cursor_screen.y + 80,
			16,
			"HP %d/%d",
			obstacle.hp,
			obstacle.meta.max_hp,
		)
	}

	when STUTTER_CHECKER_ENABLED {
		// Stutter checker
		fresnel.fill(255, 255, 255, 255)
		screen_mid := f32(state.width / 2)
		fresnel.draw_rect(
			screen_mid + math.sin(state.t * math.PI) * screen_mid * 0.9,
			f32(state.height - 32),
			2,
			32,
		)
	}
}

// TODO: Does this really belong in render? Find a better home
render_move_camera :: proc(dt: f32) {
	if e, ok := state.client.game.entities[state.client.controlling_entity_id]; ok {
		// target := vec2f(e.pos.xy)
		target := e.spring.pos
		cmd := entity_get_command(&e)
		// Move camera to midpoint between player and target... not sure I like it
		// if cmd.type == .Move && SPRINGS_ENABLED {
		// 	target = target + ((vec2f(cmd.pos) - target) / 2)
		// }
		state.client.camera.target = target
	}
	prism.spring_tick(&state.client.camera, dt, !SPRINGS_ENABLED)
}

render_tiles :: proc() {
	t0 := fresnel.now()
	grid_size := GRID_SIZE * state.client.zoom

	tiles := &state.client.game.tiles

	canvas_size := vec2f(state.width, state.height)

	rng := prism.rand_splitmix_create(GAME_SEED, RNG_TILE_VARIANCE)
	for x: i32 = 0; x < LEVEL_WIDTH; x += 1 {
		for y: i32 = 0; y < LEVEL_HEIGHT; y += 1 {
			tile_c := TileCoord{x, y}
			screen_c := screen_coord(tile_c)
			cull :=
				screen_c.x < -grid_size ||
				screen_c.y < -grid_size ||
				screen_c.x > (canvas_size.x + grid_size) ||
				screen_c.y > (canvas_size.y + grid_size)
			if cull do continue

			tile_randomiser := rng // Copy rng for this tile since we'll mutate it
			prism.rand_splitmix_add(&tile_randomiser, x)
			prism.rand_splitmix_add(&tile_randomiser, y)

			tile_below, has_tile_below := tile_at(tile_c + {0, 1}).?
			tile, ok := tile_at(tile_c).?

			when !FOG_OF_WAR_OFF {
				if .Seen not_in tile.flags do continue
			}
			if !ok do continue

			use_alternative_tile_50 := prism.rand_splitmix_get_bool(&tile_randomiser, 50)
			use_alternative_tile_500 := prism.rand_splitmix_get_bool(&tile_randomiser, 500)
			switch tile.type {
			case .Empty:
				tile_above, has_tile_above := tile_at(tile_c + {0, -1}).?
				if has_tile_above && tile_above.type == .Floor do render_sprite(SPRITE_COORD_PIT_WALL, screen_c)
			case .RopeBridge:
				render_sprite(
					use_alternative_tile_500 ? SPRITE_COORD_ROPE_BRIDGE_2 : SPRITE_COORD_ROPE_BRIDGE,
					screen_c,
				)
			case .BrickWall:
				front_facing := has_tile_below && tile_below.type != .BrickWall
				sprite :=
					front_facing ? (use_alternative_tile_50 ? SPRITE_COORD_BRICK_WALL_FACE_2 : SPRITE_COORD_BRICK_WALL_FACE) : SPRITE_COORD_BRICK_WALL_BEHIND
				render_sprite(sprite, screen_c)
			case .Floor:
				sprite :=
					use_alternative_tile_50 ? SPRITE_COORD_FLOOR_STONE_2 : SPRITE_COORD_FLOOR_STONE
				render_sprite(sprite, screen_c)
			case .Water:
				render_sprite(SPRITE_COORD_WATER, screen_c)
			}

		}
	}

	t1 := fresnel.now()
	fresnel.metric_i32("Tile loop", t1 - t0)
}

render_sprite :: proc(sprite_coords: [2]f32, pos: ScreenCoord, alpha: u8 = 255) {
	fresnel.draw_image(
		&fresnel.DrawImageArgs {
			image_id = 1,
			source_offset = sprite_coords,
			source_size = {SPRITE_SIZE, SPRITE_SIZE},
			dest_offset = pos.xy,
			dest_size = state.client.zoom * GRID_SIZE,
			alpha = alpha,
		},
	)
}

render_entities :: proc(dt: f32) {
	i: i32 = 0
	entities := &state.client.game.entities
	grid_size := GRID_SIZE * state.client.zoom

	current_player_has_ap := player_has_ap()

	for id, &e in entities {
		i += 1

		when !FOG_OF_WAR_OFF {
			tile, valid_tile := tile_at(e.pos).?
			if valid_tile && .Seen not_in tile.flags do continue
		}

		screen_c := screen_coord(TileCoordF(e.spring.pos)).xy
		canvas_size := vec2f(state.width, state.height)
		cull :=
			screen_c.x < -grid_size ||
			screen_c.y < -grid_size ||
			screen_c.x > (canvas_size.x + grid_size) ||
			screen_c.y > (canvas_size.y + grid_size)

		cmd := entity_get_command(&e)

		awaiting_cmd := e.cmd.type == .None
		has_ap := e.action_points > 0
		if id, is_player := e.player_id.?; is_player {
			is_current_player := e.id == state.client.controlling_entity_id

			alpha: u8 = has_ap && awaiting_cmd ? 255 : 128

			if cull do continue

			switch id {
			case 3:
				render_sprite(SPRITE_COORD_PLAYER_A, screen_c, alpha)
			case 2:
				render_sprite(SPRITE_COORD_PLAYER_B, screen_c, alpha)
			case 1:
				render_sprite(SPRITE_COORD_PLAYER_C, screen_c, alpha)
			case:
				render_sprite(e.meta.spritesheet_coord, screen_c, alpha)
			}

			if is_current_player {
				render_sprite(
					SPRITE_COORD_ACTIVE_CHEVRON,
					screen_coord(TileCoordF(e.spring.pos) + TileCoordF({0, -0.5})),
					has_ap ? 255 : 50,
				)
			} else {
				if has_ap && awaiting_cmd && !current_player_has_ap {
					render_sprite(
						SPRITE_COORD_THOUGHT_BUBBLE,
						screen_coord(tile_coord_f(e.pos) + TileCoordF({0.75, -0.75})),
					)
				}
			}

			if cmd.type == .Move {
				render_path_to(cmd.pos, e.id, 120)
			}
			if cmd.type == .Attack {
				tgt, ok := entity(cmd.target_entity).?
				if ok do render_path_to(tgt.pos, e.id, 120)
			}
		} else {
			if cull do continue
			render_sprite(e.meta.spritesheet_coord, screen_c)
		}

		if e.hp < e.meta.max_hp {
			_render_hitpoints(e.hp, e.meta.max_hp, screen_c, {1, f32(1) / f32(8)} * grid_size)
		}

		if entity_alignment_to_player(&e) == .Friendly {
			if cmd.type == .Move {
				render_sprite(SPRITE_COORD_FOOTSTEPS, screen_coord(cmd.pos))
			}
			if cmd.type == .Attack {
				target, target_valid := entity(cmd.target_entity).?
				if target_valid do render_sprite(SPRITE_COORD_CURSOR_ATTACK, screen_coord(target.pos))
			}
		}
	}

	fresnel.metric_i32("entities rendered", i)
}

@(private = "file")
_render_hitpoints :: proc(hp: i32, max_hp: i32, screen_coord: ScreenCoord, size: Vec2f) {
	pct := f32(hp) / f32(max_hp)
	fresnel.fill(0, 0, 0, 255)
	fresnel.draw_rect(screen_coord.x, screen_coord.y, size.x, size.y)
	fresnel.fill(255, 0, 0, 255)
	fresnel.draw_rect(screen_coord.x, screen_coord.y, size.x * pct, size.y)
}

render_tile_cursors :: proc(dt: f32) {

	if !state.client.cursor_hidden {
		// Draw this player's cursor
		if command_for_tile(state.client.cursor_pos).type == .Move {
			render_sprite(SPRITE_COORD_RECT, screen_coord(state.client.cursor_pos))
			render_sprite(SPRITE_COORD_FOOTSTEPS, screen_coord(state.client.cursor_pos))
		}
		if command_for_tile(state.client.cursor_pos).type == .Attack {
			render_sprite(SPRITE_COORD_RECT, screen_coord(state.client.cursor_pos))
		}
		if command_for_tile(state.client.cursor_pos).type == .Skip {
			render_sprite(SPRITE_COORD_RECT, screen_coord(state.client.cursor_pos))
		}
		if state.debug.render_debug_overlays {
			render_sprite(SPRITE_COORD_RECT, screen_coord(state.client.cursor_pos))
		}
	}

	// Draw other players' cursors
	for _, &p in state.client.game.players {
		if p.player_id != state.client.player_id {
			// Like render_move_camera, does this spring logic belong in a separate system (like an animation system)?
			p.cursor_spring.target = vec2f(p.cursor_tile)
			prism.spring_tick(&p.cursor_spring, dt)

			if p.cursor_updated_at == 0 || (state.t - p.cursor_updated_at > 3) {
				// Don't render stale cursors
				continue
			}

			cursor_pos := screen_coord(TileCoordF(p.cursor_spring.pos))
			text_pos := screen_coord(TileCoordF(p.cursor_spring.pos + {1, 0.75}))

			render_sprite(SPRITE_COORD_OTHER_PLAYER_CURSOR, cursor_pos)
			fresnel.fill(255, 255, 255, 1)
			fresnel.draw_text(text_pos.x, text_pos.y, 16, "Player")
		}
	}
}

render_fx :: proc(dt: f32) {
	iter := prism.pool_iterator(&state.client.fx)
	for fx, id in prism.pool_iterate(&iter) {
		fx_process(id, fx)

		coord := screen_coord(fx.pos)

		offset := (state.t - fx.t0) * Vec2f({0, -50}) + Vec2f{0, -32}
		coord = coord + ScreenCoord(offset)

		switch fx.type {
		case .MissIndicator:
			fresnel.fill(255, 255, 255, 255)
			fresnel.draw_text(coord.x, coord.y, 16 * i32(state.client.zoom), "MISS")

		case .HitIndicator:
			fresnel.fill(255, 0, 0, 255)
			s := fmt.bprintf(_tmp_16k[:], "%d", fx.dmg)
			fresnel.draw_text(coord.x, coord.y, 16 * i32(state.client.zoom), s)
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

@(private = "file")
_should_cull :: proc(screen_c: ScreenCoord, tile_size: f32 = 1.0) -> bool {
	grid_size := state.client.zoom * GRID_SIZE
	return(
		screen_c.x < -grid_size ||
		screen_c.y < -grid_size ||
		screen_c.x > (f32(state.width) + grid_size) ||
		screen_c.y > (f32(state.height) + grid_size) \
	)
}

@(private = "file")
_visualise_djikstra :: proc(dmap: ^prism.DjikstraMap($Width, $Height), offset: [2]i32 = {0, 0}) {
	if dmap.state == .Empty {
		return
	}

	for x: i32 = 0; x < Width; x += 1 {
		for y: i32 = 0; y < Height; y += 1 {
			coord := TileCoord{x + offset.x, y + offset.y}
			dtile, ok := prism.djikstra_tile(dmap, Vec2i(coord)).?
			if ok {
				offset := screen_coord(coord)
				dims := GRID_SIZE * state.client.zoom

				if _should_cull(offset) do continue

				cost, has_cost := dtile.cost.?
				// trace("DMap %w", pcg.djikstra_map._queue, pcg.djikstra_map.done)
				if has_cost {
					if cost == 0 {
						fresnel.fill(0, 255, 0, 0.8)
					} else {
						col := (f32(cost) / f32(dmap.max_cost)) * 255
						fresnel.fill(255 - col, 100, col, 0.3)
					}
					fresnel.draw_rect(offset.x, offset.y, dims, dims)

					cost_str := fmt.bprintf(_tempstr_buf[:], "%d", cost)
					fresnel.fill(255, 255, 255, 0.5)
					fresnel.draw_text(offset.x, offset.y, 16, cost_str)
				} else if dtile.visited {
					fresnel.fill(255, 0, 0, 0.5)
					fresnel.draw_rect(offset.x, offset.y, dims, dims)
				}
			}
		}
	}
}

render_path_to :: proc(
	from_pos: TileCoord,
	to_entity: EntityId = state.client.controlling_entity_id,
	alpha: u8 = 255,
) {
	dmap, e := derived_djikstra_map_to(to_entity)
	if dmap.state == .Empty do return

	path_len := prism.djikstra_path(dmap, tmp_path[:], Vec2i(from_pos))

	for p in tmp_path[:path_len] {
		offset := screen_coord(TileCoord(p))
		dims := GRID_SIZE * state.client.zoom
		fresnel.fill(0, 255, 0, 1.0)
		fresnel.draw_image(
			&fresnel.DrawImageArgs {
				image_id      = 1,
				dest_offset   = Vec2f(offset),
				dest_size     = {dims, dims},
				source_offset = SPRITE_COORD_DOT,
				// source_offset = SPRITE_COORD_FOOTSTEPS,
				source_size   = SPRITE_SIZE,
				alpha         = alpha,
			},
		)
	}
}
