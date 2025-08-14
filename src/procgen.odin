package main

import "core:container/priority_queue"
import "core:math/noise"
import "core:mem"
import "fresnel"
import "prism"

// For procgen
@(private = "file")
pcg_memory: [102_400]u8
@(private = "file")
pcg_arena: mem.Arena
@(private = "file")
pcg_alloc: mem.Allocator

@(private = "file")
RoomId :: distinct int

@(private = "file")
Room :: struct {
	aabb: prism.Aabb(i32),
}
RoomType :: enum {
	Normal,
	Pit,
}
PcgState :: struct {
	iteration:       int,
	delay:           int,
	done:            bool,
	rooms:           map[RoomId]Room,
	room_type_count: [RoomType]int,
	newest_room_id:  RoomId,
	level_bounds:    prism.Aabb(i32),
	door_locations:  priority_queue.Priority_Queue(PossibleDoorLocation),
	total_time:      i32,
	djikstra_map:    prism.DjikstraMap(LEVEL_WIDTH, LEVEL_HEIGHT),

	// Just for visualisation
	cursor:          prism.Aabb(i32),
	cursor2:         prism.Aabb(i32),
}

@(private = "file")
PossibleDoorLocation :: struct {
	pos:         TileCoord,
	direction:   prism.Direction,
	attempts:    int,
	tie_breaker: u64,
}

procgen_init :: proc(pcg: ^PcgState) {
	mem.arena_init(&pcg_arena, pcg_memory[:])
	pcg_alloc := mem.arena_allocator(&pcg_arena)
	context.allocator = pcg_alloc

	pcg.rooms = make(map[RoomId]Room, 100)
	priority_queue.init(
		&pcg.door_locations,
		_pq_less,
		priority_queue.default_swap_proc(PossibleDoorLocation),
		1000,
	)
	pcg.level_bounds = prism.Aabb(i32) {
		x2 = LEVEL_WIDTH - 1,
		y2 = LEVEL_HEIGHT - 1,
	}
}
procgen_reset :: proc(pcg: ^PcgState) {
	pcg.done = false
	pcg.iteration = 0
	pcg.total_time = 0
	pcg.newest_room_id = 0
	pcg.delay = 0
	clear(&pcg.rooms)
	pcg.room_type_count = {}
	priority_queue.clear(&pcg.door_locations)
}

procgen_iterate :: proc(pcg: ^PcgState) {
	// Debug tool: Delay iterations to help with visualisation
	when PCG_ITERATION_DELAY > 0 {
		if pcg.delay < PCG_ITERATION_DELAY {
			pcg.delay += 1
			return
		} else {
			pcg.delay = 0
		}
	}

	if pcg.iteration >= 1000 || len(pcg.rooms) >= 50 {
		info("Procedural generation done in %d iterations, %dms", pcg.iteration, pcg.total_time)

		when !NO_ENEMIES {
			_add_grass()
			_spawn_enemies()
		}

		pcg.done = true
		return
	}
	pcg.iteration += 1

	_try_add_room(pcg, 5, 5)
}

@(private = "file")
_neighbour_cost :: proc(_from: [2]i32, to: [2]i32) -> f32 {
	tile, valid_tile := tile_at(TileCoord(to)).?
	if !valid_tile do return -1
	if .Traversable not_in tile.flags do return -1
	if .Slow in tile.flags do return 2
	return 1
}

@(private = "file")
_pq_less :: proc(a, b: PossibleDoorLocation) -> bool {
	if a.attempts == b.attempts do return a.tie_breaker < b.tie_breaker
	return a.attempts < b.attempts
}

@(private = "file")
_try_add_room :: proc(
	pcg: ^PcgState,
	max_x: i32 = LEVEL_WIDTH,
	max_y: i32 = LEVEL_HEIGHT,
) -> bool {
	rng := prism.rand_splitmix_create(GAME_SEED, RNG_ROOM_PLACEMENT)
	prism.rand_splitmix_add(&rng, pcg.iteration)

	room_count := len(pcg.rooms)
	first_room := room_count == 0
	min_size: i32 = room_count < 10 ? 7 : 4
	max_size: i32 = room_count < 10 ? 16 : 9

	x := prism.rand_splitmix_get_i32_range(&rng, 0, max_x)
	y := prism.rand_splitmix_get_i32_range(&rng, 0, max_y)
	width := prism.rand_splitmix_get_i32_range(&rng, min_size, max_size)
	height := prism.rand_splitmix_get_i32_range(&rng, min_size, max_size)

	door, trying_door := priority_queue.pop_safe(&pcg.door_locations)
	if trying_door {
		pcg.cursor2 = prism.Aabb(i32){door.pos.x, door.pos.y, door.pos.x + 1, door.pos.y + 1}
		if door.direction == .South {
			y = door.pos.y
			x = prism.rand_splitmix_get_i32_range(&rng, door.pos.x - (width - 2), door.pos.x)
		}
		if door.direction == .East {
			x = door.pos.x
			y = prism.rand_splitmix_get_i32_range(&rng, door.pos.y - (height - 2), door.pos.y)
		}
	}

	outer_rect := prism.Aabb(i32) {
		x1 = x,
		y1 = y,
		x2 = x + width,
		y2 = y + height,
	}
	inner_rect := prism.aabb_grow(outer_rect, Vec2i{-1, -1})
	pcg.cursor = inner_rect

	valid_room := true
	if !prism.aabb_fully_contains(pcg.level_bounds, outer_rect) do valid_room = false

	// Check for overlaps with existing rooms
	for _, room in pcg.rooms {
		if prism.aabb_overlaps(inner_rect, room.aabb) {
			valid_room = false
		}
	}

	if !valid_room {
		if trying_door {
			door.attempts += 1
			priority_queue.push(&pcg.door_locations, door)
		}
		return false
	}

	is_pit := false
	if width > 9 &&
	   height > 9 &&
	   !first_room &&
	   trying_door &&
	   prism.rand_splitmix_get_bool(&rng, 700) &&
	   pcg.room_type_count[.Pit] < 1 {
		trace("Drawing pit %v", outer_rect)
		size := Vec2i {
			prism.rand_splitmix_get_i32_range(&rng, 3, 5),
			prism.rand_splitmix_get_i32_range(&rng, 3, 5),
		}
		pos := prism.aabb_pos(inner_rect) + (prism.aabb_size(inner_rect) / 2)

		island := prism.aabb(pos, size)
		bridge_start := door.pos + (door.direction == .South ? {0, 1} : {1, 0})

		// Draw pit island room
		// tile_draw_outline(outer_rect)
		tile_draw_fill(island)
		tile_connect_region(bridge_start, island)

		game_spawn_entity(.Firebug, {pos = TileCoord(pos)})

		is_pit = true
		pcg.room_type_count[.Pit] += 1
	} else {
		// tile_draw_room(TileCoord({x, y}), Vec2i({width, height}))
		tile_draw_outline(outer_rect)
		tile_draw_fill(prism.aabb_grow(outer_rect, -1))
		pcg.room_type_count[.Normal] += 1
	}

	if trying_door do tile_draw_door(door.pos)

	if first_room {
		state.client.game.spawn_point = TileCoord {
			prism.rand_splitmix_get_i32_range(&rng, inner_rect.x1, inner_rect.x2),
			prism.rand_splitmix_get_i32_range(&rng, inner_rect.y1, inner_rect.y2),
		}
		prism.spring_reset_to(&state.client.camera, vec2f(state.client.game.spawn_point))
	}

	pcg.newest_room_id += 1
	pcg.rooms[pcg.newest_room_id] = Room {
		aabb = inner_rect,
	}

	// Skip doors for pit room
	if is_pit do return true

	for xx := inner_rect.x1 + 1; xx < inner_rect.x2; xx += 1 {
		priority_queue.push(
			&pcg.door_locations,
			PossibleDoorLocation {
				pos = TileCoord{xx, inner_rect.y2},
				direction = .South,
				tie_breaker = prism.rand_splitmix_get_u64(&rng),
				attempts = 0,
			},
		)
	}
	for yy := inner_rect.y1 + 1; yy < inner_rect.y2; yy += 1 {
		priority_queue.push(
			&pcg.door_locations,
			PossibleDoorLocation {
				pos = TileCoord{inner_rect.x2, yy},
				direction = .East,
				tie_breaker = prism.rand_splitmix_get_u64(&rng),
				attempts = 0,
			},
		)
	}

	return true
}

@(private = "file")
_add_grass :: proc() {
	region_iter := prism.aabb_iterator(prism.aabb(Vec2i{0, 0}, Vec2i{LEVEL_WIDTH, LEVEL_HEIGHT}))
	for pos in prism.aabb_iterate(&region_iter) {
		val := noise.noise_2d(1, {f64(pos.x) * 0.1, f64(pos.y) * 0.1})
		if val > 0.5 {
			tile, ok := tile_at(TileCoord(pos)).?
			if !ok do continue
			if tile.type != .Floor do continue
			tile.flags += {.Grass}
		}
	}
}

@(private = "file")
_spawn_enemies :: proc() {
	rng := prism.rand_splitmix_create(GAME_SEED, RNG_ROOM_PLACEMENT)

	spawn_max := 12
	spawned := 0
	for i := 0; i < 100 && spawned < spawn_max; i += 1 {
		x := prism.rand_splitmix_get_i32_range(&rng, 0, LEVEL_WIDTH)
		y := prism.rand_splitmix_get_i32_range(&rng, 0, LEVEL_HEIGHT)
		coord := TileCoord({x, y})

		tile, valid := tile_at(coord).?
		if !valid do continue

		if .Traversable not_in tile.flags do continue

		if prism.tile_distance(coord - state.client.game.spawn_point) < 10 do continue

		is_spider := prism.rand_splitmix_get_bool(&rng, 800)
		new_enemy := game_spawn_entity(is_spider ? .Spider : .Firebug, {pos = coord})

		spawned += 1
	}
}
