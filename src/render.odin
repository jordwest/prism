package main

import clay "clay-odin"
import "core:container/queue"
import "core:fmt"
import "core:math"
import "fresnel"
import "prism"

@(private = "file")
_tempstr_buf: [16384]u8

RenderState :: struct {
	text_input_rendered_this_frame: bool,
}

render_frame :: proc(dt: f32) {
	state.client.render.text_input_rendered_this_frame = false

	render_clear()
	render_move_camera(dt)
	render_tiles()
	render_items()
	render_entities(dt)
	render_tile_cursors(dt)
	render_fx(dt)
	if !state.client.cursor_hidden &&
	   !state.client.cursor_over_ui &&
	   command_for_tile(state.client.cursor_pos).type == .Move {
		render_path_to(state.client.cursor_pos, alpha = 80)
	}

	arena_free(&arena_ui_frame)
	render_ui(.Main)
	render_ui(.Tooltip, state.client.cursor_screen_pos + {32, 0})

	if state.debug.render_debug_overlays {
		render_debug_overlays()
	}

	if !state.client.render.text_input_rendered_this_frame {
		fresnel.remove_input()
	}
}

render_clear :: proc() {
	fresnel.clear()
	fresnel.fill(10, 10, 10, 255)
	fresnel.draw_rect(0, 0, f32(state.width), f32(state.height))
	fresnel.fill(0, 0, 0, 255)
}

@(private = "file")
_debug_y_offset: f32 = 16

@(private = "file")
_add_debug_text :: proc(fmt_str: string, args: ..any) {
	fresnel.draw_text_fmt(16, _debug_y_offset, FONT_SIZE_BASE, fmt_str, ..args)
	_debug_y_offset += FONT_SIZE_BASE
}

render_debug_overlays :: proc() {
	fresnel.fill(255, 255, 255, 255)
	_debug_y_offset = FONT_SIZE_BASE
	_add_debug_text("Debug overlays: %v", state.debug.view)
	_add_debug_text(
		"Player id=%d / entity=%d",
		state.client.player_id,
		state.client.controlling_entity_id,
	)
	_add_debug_text("Turn %d, t=%.2f", state.client.game.current_turn, state.t)
	_add_debug_text("%.0f FPS (%.0f max, %.0f min)", debug_get_fps())
	_add_debug_text("Log queue size: %d", queue.len(state.client.log_queue._queue))
	_add_debug_text(
		"%d players / %d entities",
		len(state.client.game.players),
		len(state.client.game.entities),
	)
	_add_debug_text(
		"Entity size: %db x %d = %.3fKB",
		size_of(Entity),
		cap(state.client.game.entities),
		f32(size_of(Entity) * cap(state.client.game.entities)) / 1000,
	)
	if state.client.cursor_over_ui do _add_debug_text("Cursor over UI")
	if state.host.is_host {
		_add_debug_text("host tx ↑: %.3fKB", f32(state.host.bytes_sent) / 1000)
		_add_debug_text("host rx ↓: %.3fKB", f32(state.host.bytes_received) / 1000)
	}
	_add_debug_text("tx ↑ %.3fKB", f32(state.client.bytes_sent) / 1000)
	_add_debug_text("rx ↓ %.3fKB", f32(state.client.bytes_received) / 1000)

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
		dmap, e := derived_djikstra_map_to(
			state.client.controlling_entity_id,
			dont_generate = true,
		)
		_visualise_djikstra(dmap)
	case .AllPlayersDjikstra:
		dmap, e := derived_allies_djikstra_map(dont_generate = true)
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
	cursor_screen := state.client.cursor_screen_pos + ScreenCoord{32, -32}
	fresnel.draw_text(cursor_screen.x, cursor_screen.y, FONT_SIZE_BASE, cursor_text)

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
	focused_entity, ok := entity(state.client.controlling_entity_id).?
	if state.client.join_mode == .Spectate {
		for _, player in state.client.game.players {
			if player.player_entity_id > 0 {
				focused_entity, ok = entity(player.player_entity_id).?
				break
			}
		}
	}

	if state.client.viewing_entity_id != 0 {
		focused_entity, ok = entity(state.client.viewing_entity_id).?
	}

	if !ok do return

	// target := vec2f(e.pos.xy)
	target := focused_entity.spring.pos
	cmd := entity_get_command(focused_entity)
	// Move camera to midpoint between player and target... not sure I like it
	// if cmd.type == .Move && SPRINGS_ENABLED {
	// 	target = target + ((vec2f(cmd.pos) - target) / 2)
	// }
	state.client.camera.target = target

	prism.spring_tick(&state.client.camera, dt, !SPRINGS_ENABLED)
}

render_tiles :: proc() {
	t0 := fresnel.now()
	grid_size := GRID_SIZE * state.client.zoom
	canvas_size := vec2f(state.width, state.height)

	tiles := &state.client.game.tiles

	rng := prism.rand_splitmix_create(state.client.game.seed, RNG_TILE_VARIANCE)
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
			pit_wall_tiles: bit_set[TileType] = {.Floor, .BrickWall}
			switch tile.type {
			case .Empty:
				tile_above, has_tile_above := tile_at(tile_c + {0, -1}).?
				if has_tile_above && tile_above.type in pit_wall_tiles do render_sprite(SPRITE_COORD_PIT_WALL, screen_c)
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

			if tile.fire.fuel > 0 {
				global_animation_frame := int(state.t * 8)
				render_sprite(Sprite.Fire, screen_c, frame_index = global_animation_frame)
			}

			if .Grass in tile.flags {
				render_sprite(Sprite.Grass, screen_c)
			}

		}
	}

	t1 := fresnel.now()
	fresnel.metric_i32("Tile loop", t1 - t0)
}

render_sprite :: proc {
	render_sprite_new,
	render_sprite_old,
}
render_sprite_new :: proc(sprite: Sprite, pos: ScreenCoord, frame_index := 0, alpha: u8 = 255) {
	meta := sprite_meta[sprite]
	frame := sprite_choose_frame(&meta, frame_index)

	fresnel.draw_image(
		&fresnel.DrawImageArgs {
			image_id = 1,
			source_offset = frame.offset,
			source_size = {SPRITE_SIZE, SPRITE_SIZE},
			dest_offset = pos.xy,
			dest_size = state.client.zoom * GRID_SIZE,
			alpha = alpha,
		},
	)
}

render_sprite_old :: proc(sprite_coords: [2]f32, pos: ScreenCoord, alpha: u8 = 255) {
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

render_items :: proc() {
	grid_size := GRID_SIZE * state.client.zoom
	canvas_size := vec2f(state.width, state.height)

	for container_id, _ in &state.client.game.containers.index {
		if coord, ok := container_id.(prism.TileCoord); ok {
			screen_c := screen_coord(coord)
			cull :=
				screen_c.x < -grid_size ||
				screen_c.y < -grid_size ||
				screen_c.x > (canvas_size.x + grid_size) ||
				screen_c.y > (canvas_size.y + grid_size)
			if cull do continue

			tile, valid_tile := tile_at(coord).?
			if !valid_tile do continue
			if .Seen not_in tile.flags do continue

			iter := container_iterator(container_id)
			// Only render one item
			item, _, ok := container_iterate(&iter)
			if !ok do continue
			switch t in item.type {
			case PotionType:
				render_sprite(Sprite.Potion, screen_c)
			}
		}
	}
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

			if is_current_player && !player_is_alone() {
				bounce_offset_y := has_ap ? math.sin(state.t * 5) * 0.25 : 0
				render_sprite(
					SPRITE_COORD_ACTIVE_CHEVRON,
					screen_coord(
						TileCoordF(e.spring.pos) + TileCoordF({0, -0.5 + bounce_offset_y}),
					),
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

		if state.t - e.t_last_hurt < 0.05 {
			render_sprite(Sprite.HitEffect, screen_c)
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

	if state.client.cursor_over_ui do return

	if !state.client.cursor_hidden {
		// Draw this player's cursor
		if command_for_tile(state.client.cursor_pos).type == .Move {
			render_sprite(SPRITE_COORD_RECT, screen_coord(state.client.cursor_pos), alpha = 100)
			render_sprite(SPRITE_COORD_FOOTSTEPS, screen_coord(state.client.cursor_pos))
		}
		if command_for_tile(state.client.cursor_pos).type == .Attack {
			// render_sprite(SPRITE_COORD_RECT, screen_coord(state.client.cursor_pos))
			render_sprite(SPRITE_COORD_CURSOR_ATTACK, screen_coord(state.client.cursor_pos))
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
			fresnel.draw_text(
				text_pos.x,
				text_pos.y,
				FONT_SIZE_BASE,
				prism.bufstring_as_str(&p.display_name),
			)
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
			fresnel.draw_text(coord.x, coord.y, FONT_SIZE_BASE, "MISS")

		case .HitIndicator:
			fresnel.fill(255, 0, 0, 255)
			s := fmt.bprintf(_tmp_16k[:], "%d", fx.dmg)
			fresnel.draw_text(coord.x, coord.y, FONT_SIZE_BASE, s)
		}
	}
}

UiContext :: enum {
	Main,
	Tooltip,
}

render_ui :: proc(ui: UiContext, offset_in: ScreenCoord = {0, 0}) {
	ctx := ui == .Main ? ctx1 : ctx2
	clay.SetCurrentContext(ctx)
	render_commands := ui == .Main ? ui_layout_screen() : ui_layout_tooltip()

	offset := offset_in

	if ui == .Tooltip {
		dat := clay.GetElementData(clay.ID("TooltipSizer"))
		if offset.x + dat.boundingBox.width > f32(state.width) do offset.x += -dat.boundingBox.width + -64
		if offset.y + dat.boundingBox.height > f32(state.height) do offset.y += -dat.boundingBox.height
		if offset.x <= 0 {
			// Still doesn't fit on screen, anchor to left of screen and push it below the cursor a bit
			offset.x = 0
			offset.y += 32
		}
		if offset.y <= 0 {
			offset.y = 0
		}
	}

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
				render_command.boundingBox.x + offset.x,
				render_command.boundingBox.y + offset.y,
				render_command.boundingBox.width,
				render_command.boundingBox.height,
			)
		case .Text:
			c := render_command.renderData.text.textColor
			fresnel.fill(c.r, c.g, c.b, c.a)
			fresnel.draw_text(
				render_command.boundingBox.x + offset.x,
				render_command.boundingBox.y + offset.y,
				i32(render_command.renderData.text.fontSize),
				string_from_clay_slice(render_command.renderData.text.stringContents),
			)
		case .Custom:
			el := (^CustomClayElement)(render_command.renderData.custom.customData)
			switch custom in el {
			case TextInput:
				state.client.render.text_input_rendered_this_frame = true
				fresnel.render_input(
					render_command.boundingBox.x,
					render_command.boundingBox.y,
					render_command.boundingBox.width,
					i32(render_command.boundingBox.height),
					custom.value,
				)
			}
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
					fresnel.draw_text(offset.x, offset.y, FONT_SIZE_BASE, cost_str)
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
	dmap, e := derived_djikstra_map_to(to_entity, dont_generate = true)
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
