package main

import "prism"

// Assign a new entity ID and return it (does not yet spawn it, it doesn't live anywhere except on the stack!)
game_spawn_entity :: proc(entity: Entity) -> ^Entity {
	state.client.game.newest_entity_id += 1
	id := EntityId(state.client.game.newest_entity_id)

	state.client.game.entities[id] = entity
	new_entity := &state.client.game.entities[id]

	new_entity.id = id
	new_entity.flags = entity_meta[new_entity.meta_id].flags

	derived_clear()

	return new_entity
}

game_calculate_move_cost :: proc(_from: [2]i32, to: [2]i32) -> i32 {
	tile, valid_tile := tile_at(&state.client.game.tiles, TileCoord(to)).?
	if !valid_tile do return -1
	entities := derived_entities_at(TileCoord(to))
	if obstacle, has_obstacle := entities.obstacle.?; has_obstacle {
		if .CanMove not_in obstacle.flags do return -1
	}
	if .Traversable not_in tile_flags[tile.type] do return -1
	if .Slow in tile_flags[tile.type] do return 2
	return 1
}

// Get the command that will be set if a given tile is clicked on (or walked into)
game_command_for_tile :: proc(coord: TileCoord) -> Command {
	tile, valid_tile := tile_at(&state.client.game.tiles, TileCoord(coord)).?
	if !valid_tile do return Command{}
	if .Traversable not_in tile_flags[tile.type] do return Command{}

	obstacle, has_obstacle := game_entity_at(coord, entity_is_obstacle).?

	if has_obstacle {
		if .CanSwapPlaces in obstacle.flags {
			return Command{type = .Move, pos = coord}
		} else {
			return Command{}
		}
	}

	return Command{type = .Move, pos = coord}
}

game_entity_at :: proc(
	pos: TileCoord,
	filter := proc(_: ^Entity) -> bool {return true},
) -> Maybe(^Entity) {
	entity: [1]^Entity

	count := game_entities_at(pos, entity[:], filter)

	if count == 1 do return entity[0]
	return nil
}

game_entities_at :: proc(
	pos: TileCoord,
	out_entities: []^Entity,
	filter := proc(_: ^Entity) -> bool {return true},
) -> (
	count: int,
) {
	max_iterations := len(out_entities)
	count = 0

	for _, &entity in state.client.game.entities {
		if count >= max_iterations do return
		if entity.pos == pos && filter(&entity) {
			out_entities[count] = &entity
			count += 1
		}
	}

	return count
}

@(private = "file")
temp_entities: [20]^Entity

game_find_nearest_traversable_space :: proc(
	start: TileCoord,
	max_distance: i32 = 10,
) -> (
	out_coord: TileCoord,
	ok: bool,
) {
	distance: i32 = 0
	coord: TileCoord

	for dist: i32 = 0; dist < max_distance; dist += 1 {
		aabb := prism.Aabb(i32) {
			x1 = start.x - dist,
			x2 = start.x + dist,
			y1 = start.y - dist,
			y2 = start.y + dist,
		}

		for x := aabb.x1; x <= aabb.x2; x += 1 {
			for y := aabb.y1; y <= aabb.y2; y += 1 {
				if prism.aabb_is_edge(aabb, [2]i32{x, y}) {
					trace("Checking coord %d, %d", x, y)
					// Evaluate tile
					out_coord = TileCoord{x, y}
					tile, valid_tile := tile_at(&state.client.game.tiles, out_coord).?
					if !valid_tile do continue
					if game_entities_at(out_coord, temp_entities[:], entity_is_obstacle) > 0 do continue
					if .Traversable in tile_flags[tile.type] do return out_coord, true
				}
			}
		}
	}

	return {}, false
}
