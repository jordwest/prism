package main

import "core:container/priority_queue"
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
PcgState :: struct {
	iteration:      int,
	delay:          int,
	done:           bool,
	tiles:          [LEVEL_WIDTH * LEVEL_HEIGHT]PcgTile,
	rooms:          map[RoomId]Room,
	newest_room_id: RoomId,
	level_bounds:   prism.Aabb(i32),
	door_locations: priority_queue.Priority_Queue(PossibleDoorLocation),
	total_time:     i32,

	// Just for visualisation
	cursor:         prism.Aabb(i32),
	cursor2:        prism.Aabb(i32),
}

@(private = "file")
PcgTile :: struct {
	// flags: PcgTileFlag,
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

	pcg.iteration += 1
	if pcg.iteration > 1000 || len(pcg.rooms) >= 50 {
		info("Procedural generation done in %dms", pcg.total_time)
		pcg.done = true
		return
	}

	_try_add_room(pcg, 5, 5)
}

@(private = "file")
_pq_less :: proc(a, b: PossibleDoorLocation) -> bool {
	if a.attempts == b.attempts {
		return a.tie_breaker < b.tie_breaker
	}
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

	room_walls_aabb := prism.Aabb(i32) {
		x1 = x,
		y1 = y,
		x2 = x + width,
		y2 = y + height,
	}
	room_aabb := prism.aabb_grow(room_walls_aabb, Vec2i{-1, -1})
	pcg.cursor = room_aabb

	valid_room := true
	if !prism.aabb_fully_contains(pcg.level_bounds, room_walls_aabb) do valid_room = false

	// Check for overlaps with existing rooms
	for _, room in pcg.rooms {
		if prism.aabb_overlaps(room_aabb, room.aabb) {
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

	tile_draw_room(TileCoord({x, y}), Vec2i({width, height}))
	if trying_door do tile_draw_door(door.pos)

	pcg.newest_room_id += 1
	pcg.rooms[pcg.newest_room_id] = Room {
		aabb = room_aabb,
	}

	for xx := room_aabb.x1 + 1; xx < room_aabb.x2; xx += 1 {
		priority_queue.push(
			&pcg.door_locations,
			PossibleDoorLocation {
				pos = TileCoord{xx, room_aabb.y2},
				direction = .South,
				tie_breaker = prism.rand_splitmix_get_u64(&rng),
				attempts = 0,
			},
		)
	}
	for yy := room_aabb.y1 + 1; yy < room_aabb.y2; yy += 1 {
		priority_queue.push(
			&pcg.door_locations,
			PossibleDoorLocation {
				pos = TileCoord{room_aabb.x2, yy},
				direction = .East,
				tie_breaker = prism.rand_splitmix_get_u64(&rng),
				attempts = 0,
			},
		)
	}

	return true
}
