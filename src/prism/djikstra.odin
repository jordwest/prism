package prism
import "core:container/queue"
import "core:math"
import "core:math/bits"
import "core:mem"

DjikstraError :: enum u8 {
	Ok = 0,
	DjikstraAlgoInUse,
	NotInitialized,
	InvalidTile,
}

DjikstraMapState :: enum {
	Empty = 0,
	PartiallyComplete,
	Complete,
}

DjikstraMap :: struct($Width: i32, $Height: i32) {
	state:          DjikstraMapState,
	tiles:          [Width * Height]DjikstraTile,
	max_cost:       i32,
	max_cost_coord: [2]i32,
	iterations:     i32,
}

DjikstraAlgo :: struct($Width: i32, $Height: i32) {
	_current_map: Maybe(^DjikstraMap(Width, Height)),
	_queue:       queue.Queue([2]i32),
	_move_cost:   proc(from: [2]i32, to: [2]i32) -> i32,
}

DjikstraTile :: struct {
	visited: bool,
	cost:    Maybe(i32),
}

djikstra_init :: proc(
	djikstra_algo: ^DjikstraAlgo($Width, $Height),
	allocator: mem.Allocator = context.allocator,
) -> mem.Allocator_Error {
	// Assume frontier is unlikely to be larger than covering every edge of the map
	queue.init(&djikstra_algo._queue, int(Width * 2 + Height * 2)) or_return
	djikstra_algo._move_cost = proc(from: [2]i32, to: [2]i32) -> i32 {return 1}
	return nil
}

djikstra_map_init :: proc(
	dmap: ^DjikstraMap($Width, $Height),
	algo: ^DjikstraAlgo(Width, Height),
) -> DjikstraError {
	if algo._current_map != nil {
		return .DjikstraAlgoInUse
	}

	// Clear existing data first
	queue.clear(&algo._queue)
	dmap.state = .Empty
	dmap.max_cost = 0
	dmap.max_cost_coord = {0, 0}
	dmap.iterations = 0
	mem.zero_slice(dmap.tiles[:])

	algo._current_map = dmap

	return nil
}

djikstra_map_add_origin :: proc(
	algo: ^DjikstraAlgo($Width, $Height),
	coord: [2]i32,
) -> DjikstraError {
	dmap, initialized := algo._current_map.(^DjikstraMap(Width, Height))
	if !initialized do return .NotInitialized

	queue.push_back(&algo._queue, coord)
	tile, valid_tile := djikstra_tile(dmap, coord).?
	if !valid_tile do return .InvalidTile
	tile.visited = true
	tile.cost = 0

	return nil
}

djikstra_map_generate :: proc(
	algo: ^DjikstraAlgo($Width, $Height),
	move_cost: proc(from: [2]i32, to: [2]i32) -> i32,
	max_iterations := 1000,
) -> DjikstraError {
	dmap, initialized := algo._current_map.(^DjikstraMap(Width, Height))
	if !initialized do return .NotInitialized

	algo._move_cost = move_cost

	dmap.state = .PartiallyComplete
	for i := 0; i < max_iterations && dmap.state != .Complete; i += 1 {
		_iterate(algo, dmap)
	}

	algo._current_map = nil
	return nil
}

djikstra_tile :: proc(
	djikstra_map: ^DjikstraMap($Width, $Height),
	coord: [2]i32,
) -> Maybe(^DjikstraTile) {
	if coord.x >= Width || coord.x < 0 || coord.y < 0 {
		return nil
	}
	idx := _idx(Width, coord)
	if idx < 0 || idx >= len(djikstra_map.tiles) {
		return nil
	}
	return &djikstra_map.tiles[idx]
}

djikstra_path :: proc(
	dmap: ^DjikstraMap($Width, $Height),
	path_out: [][2]i32,
	start_at: [2]i32,
) -> (
	steps: i32,
) {
	coord := start_at
	max_iterations := i32(len(path_out))
	for steps = 0; steps < max_iterations; steps += 1 {
		next_coord, cost, ok := djikstra_next(dmap, coord)
		if !ok do break // No valid next tile
		if cost == 0 do break // Finished pathing to origin
		coord = next_coord
		path_out[steps] = coord
	}

	return steps
}

djikstra_next :: proc(
	dmap: ^DjikstraMap($Width, $Height),
	coord_in: [2]i32,
) -> (
	coord_out: [2]i32,
	lowest_cost: i32,
	ok: bool,
) {
	coord_out = coord_in
	ok = false

	tile, valid_tile := djikstra_tile(dmap, coord_in).?
	if !valid_tile do return

	lowest_cost = tile.cost.? or_else bits.I32_MAX

	for offset in NEIGHBOUR_TILES_8D {
		check_coord := coord_in + offset
		tile, valid_tile := djikstra_tile(dmap, check_coord).?
		if valid_tile {
			if cost, has_cost := tile.cost.?; has_cost {
				if cost < lowest_cost {
					lowest_cost = cost
					coord_out = check_coord
					ok = true
				}
			}
		}
	}

	return coord_out, lowest_cost, ok
}

@(private = "file")
_idx :: proc(width: i32, coord: [2]i32) -> i32 {
	return coord.x + coord.y * width
}

@(private = "file")
_iterate :: proc(algo: ^DjikstraAlgo($Width, $Height), dmap: ^DjikstraMap(Width, Height)) {
	current_coord, ok := queue.pop_front_safe(&algo._queue)
	if !ok {
		// No more tiles to check, we're done
		dmap.state = .Complete
		algo._current_map = nil
		return
	}

	this_tile, valid_tile := djikstra_tile(dmap, current_coord).?
	if !valid_tile {
		return
	}
	this_tile_cost := this_tile.cost.? or_else 0

	neighbours: []([2]i32) = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}, {1, 1}, {-1, -1}, {1, -1}, {-1, 1}}
	// neighbours: []([2]i32) = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}

	for neighbour_offset in neighbours {
		dmap.iterations += 1
		new_coord := current_coord + neighbour_offset
		neighbour_tile, valid_next_tile := djikstra_tile(dmap, new_coord).?
		// if !valid_next_tile || neighbour_tile.visited {
		if !valid_next_tile {
			continue
		}

		move_cost := algo._move_cost(current_coord, new_coord)
		neighbour_tile.visited = true
		if move_cost >= 0 {
			new_cost := this_tile_cost + move_cost

			old_cost, already_has_cost := neighbour_tile.cost.?

			if already_has_cost {
				if new_cost < old_cost do neighbour_tile.cost = new_cost
				continue
			}

			neighbour_tile.cost = new_cost
			if new_cost > dmap.max_cost {
				dmap.max_cost = new_cost
				dmap.max_cost_coord = new_coord
			}
			queue.push_back(&algo._queue, new_coord)
		}
	}
}
