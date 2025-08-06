package prism
import "core:container/queue"
import "core:math"
import "core:mem"

DjikstraMap :: struct($Width: i32, $Height: i32) {
	done:       bool,
	tiles:      [Width * Height]DjikstraTile,
	max_cost:   f32,
	iterations: i32,
	_queue:     queue.Queue([2]i32),
	_move_cost: proc(from: [2]i32, to: [2]i32) -> f32,
}

DjikstraTile :: struct {
	visited: bool,
	cost:    Maybe(f32),
}

djikstra_init :: proc(
	djikstra_map: ^DjikstraMap($Width, $Height),
	move_cost: proc(from: [2]i32, to: [2]i32) -> f32,
	allocator: mem.Allocator = context.allocator,
) -> mem.Allocator_Error {
	// Assume frontier is unlikely to be larger than covering every edge of the map
	queue.init(&djikstra_map._queue, int(Width * 2 + Height * 2)) or_return
	djikstra_map._move_cost = move_cost
	return nil
}

djikstra_clear :: proc(djikstra_map: ^DjikstraMap($Width, $Height)) {
	// Assume frontier is unlikely to be larger than covering every edge of the map
	queue.clear(&djikstra_map._queue)
	djikstra_map.done = false
	djikstra_map.max_cost = 0
	djikstra_map.iterations = 0
	mem.zero_slice(djikstra_map.tiles[:])
	// for i := 0; i < len(djikstra_map.tiles); i += 1 { djikstra_map.tiles[i] = DjikstraTile{}
	// }
}

djikstra_add_origin :: proc(djikstra_map: ^DjikstraMap($Width, $Height), coord: [2]i32) {
	queue.push_back(&djikstra_map._queue, coord)
	tile, ok := djikstra_tile(djikstra_map, coord).?
	if !ok {
		return
	}
	tile.visited = true
	tile.cost = 0
}

djikstra_iterate :: proc(djikstra_map: ^DjikstraMap($Width, $Height), max_iterations := 1000) {
	for i := 0; i < max_iterations && !djikstra_map.done; i += 1 {
		_iterate(djikstra_map)
	}
}

djikstra_tile :: proc(
	djikstra_map: ^DjikstraMap($Width, $Height),
	coord: [2]i32,
) -> Maybe(^DjikstraTile) {
	if coord.x >= Width {
		return nil
	}
	idx := _idx(Width, coord)
	if idx < 0 || idx >= len(djikstra_map.tiles) {
		return nil
	}
	return &djikstra_map.tiles[idx]
}

@(private = "file")
_idx :: proc(width: i32, coord: [2]i32) -> i32 {
	return coord.x + coord.y * width
}

@(private = "file")
_iterate :: proc(dmap: ^DjikstraMap($Width, $Height)) {
	current_coord, ok := queue.pop_front_safe(&dmap._queue)
	if !ok {
		// No more tiles to check, we're done
		dmap.done = true
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
		neighbour_coord := current_coord + neighbour_offset
		neighbour_tile, valid_next_tile := djikstra_tile(dmap, neighbour_coord).?
		// if !valid_next_tile || neighbour_tile.visited {
		if !valid_next_tile {
			continue
		}

		move_cost := dmap._move_cost(current_coord, neighbour_coord)
		neighbour_tile.visited = true
		if move_cost >= 0 {
			new_cost := this_tile_cost + move_cost

			old_cost, already_has_cost := neighbour_tile.cost.?

			if already_has_cost {
				if new_cost < old_cost do neighbour_tile.cost = new_cost
				continue
			}

			neighbour_tile.cost = new_cost
			dmap.max_cost = math.max(new_cost, dmap.max_cost)
			queue.push_back(&dmap._queue, neighbour_coord)
		}
	}
}
