package main

import "core:math"
import "prism"

MoveModifier :: enum {
	Normal, // Normal move
	Blocked, // Cannot move there
	Slow, // Slowed by terrain
}

// Assign a new entity ID and return it (does not yet spawn it, it doesn't live anywhere except on the stack!)
game_spawn_entity :: proc(meta_id: EntityMetaId, entity: Entity = Entity{}) -> ^Entity {
	state.client.game.newest_entity_id += 1
	id := EntityId(state.client.game.newest_entity_id)

	state.client.game.entities[id] = entity

	new_entity := &state.client.game.entities[id]
	new_entity.id = id
	new_entity.meta = entity_meta[meta_id]
	new_entity.hp = new_entity.meta.max_hp

	derived_handle_entity_changed(new_entity)

	return new_entity
}

game_get_move_modifier :: proc(
	from: TileCoord,
	to: TileCoord,
) -> (
	modifier: MoveModifier,
	avoid: bool,
) {
	tile, valid_tile := tile_at(TileCoord(to)).?
	if !valid_tile do return .Blocked, false
	entities := derived_entities_at(TileCoord(to))
	if .Traversable not_in tile_flags[tile.type] do return .Blocked, false
	if obstacle, has_obstacle := entities.obstacle.?; has_obstacle {
		if .CanMove not_in obstacle.meta.flags do return .Blocked, false
		avoid = true
	}
	if .Slow in tile_flags[tile.type] do return .Slow, avoid
	return .Normal, avoid
}

game_move_modifier_to_cost :: proc(modifier: MoveModifier) -> i32 {
	switch modifier {
	case .Blocked:
		return -1
	case .Normal:
		return 100
	case .Slow:
		return 200
	}
	return 100
}

game_calculate_move_cost :: proc(from: TileCoord, to: TileCoord) -> i32 {
	modifier, _ := game_get_move_modifier(TileCoord(from), TileCoord(to))
	return game_move_modifier_to_cost(modifier)
}

game_calculate_move_cost_djikstra :: proc(from: [2]i32, to: [2]i32) -> i32 {
	modifier, avoid := game_get_move_modifier(TileCoord(from), TileCoord(to))
	cost := game_move_modifier_to_cost(modifier)
	if cost < 0 do return cost

	// Add a slight increase to discourage diagonals
	// if math.abs(to.x - from.x) + math.abs(to.y - from.y) > 1 do cost += 10

	// Add cost to avoid this tile
	// if avoid do cost += 100

	return cost
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
	tile_entities := derived_entities_at(pos, true)
	if tile_entities.ground == nil && tile_entities.obstacle == nil do return 0

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

game_is_coord_free :: proc(coord: [2]i32) -> bool {
	_, has_entities := derived_entities_at(TileCoord(coord)).obstacle.?
	return !has_entities
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
					// Evaluate tile
					out_coord = TileCoord{x, y}
					tile, valid_tile := tile_at(out_coord).?
					if !valid_tile do continue
					entity_tile := derived_entities_at(out_coord)
					if entity_tile.obstacle != nil do continue
					if .Traversable in tile_flags[tile.type] do return out_coord, true
				}
			}
		}
	}

	return {}, false
}
