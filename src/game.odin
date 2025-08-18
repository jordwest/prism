package main

import "core:math"
import "core:mem"
import "prism"

MoveModifier :: enum {
	Blocked, // Cannot move there
	Slow, // Slowed by terrain
	Avoid, // Traversable but avoid if possible
	Unseen, // This tile hasn't been seen by player team yet
}

// Assign a new entity ID and return it (does not yet spawn it, it doesn't live anywhere except on the stack!)
game_spawn_entity :: proc(meta_id: EntityMetaId, entity: Entity = Entity{}) -> ^Entity {
	state.client.game.newest_entity_id += 1
	id := EntityId(state.client.game.newest_entity_id)

	state.client.game.entities[id] = entity

	new_entity := &state.client.game.entities[id]
	new_entity.id = id
	new_entity.meta_id = meta_id
	new_entity.meta = entity_meta[meta_id]
	if GOD_MODE && meta_id == .Player do new_entity.meta.max_hp = 100000000
	new_entity.hp = new_entity.meta.max_hp

	derived_handle_entity_changed(new_entity)

	return new_entity
}

game_reset :: proc() {
	game := &state.client.game
	game.current_turn = 0
	game.enemies_killed = 0
	game.newest_entity_id = 0
	derived_clear()
	game.turn_complete = false
	game.status = .Lobby
	clear(&state.client.game.entities)
	procgen_reset(state.client.game.pcg.?)
	items_reset()
}

game_get_move_modifier :: proc(
	from: TileCoord,
	to: TileCoord,
) -> (
	modifiers: bit_set[MoveModifier],
) {
	tile, valid_tile := tile_at(TileCoord(to)).?
	if !valid_tile do return {.Blocked}
	if .Seen not_in tile.flags do modifiers += {.Unseen}
	entities := derived_entities_at(TileCoord(to))
	if .Traversable not_in tile.flags do return {.Blocked}
	if obstacle, has_obstacle := entities.obstacle.?; has_obstacle && !obstacle.despawning {
		moved_recently :=
			.MovedLastTurn in obstacle.meta.flags || .MovedThisTurn in obstacle.meta.flags
		if !moved_recently do return {.Blocked}
		modifiers += {.Avoid}
	}
	if .Slow in tile.flags do modifiers += {.Slow}
	return modifiers
}

game_check_lose_condition :: proc() {
	for _, player in state.client.game.players {
		entity, ok := entity(player.player_entity_id).?
		// A player is still alive, game is not over
		if ok && !entity.despawning do return
	}

	event_fire(EventGameOver{})
}

game_move_modifiers_to_cost :: proc(modifiers: bit_set[MoveModifier]) -> i32 {
	cost: i32 = 100
	if .Blocked in modifiers do return -1
	if .Slow in modifiers do cost += 100
	return cost
}

game_calculate_move_cost :: proc(entity: ^Entity, from: TileCoord, to: TileCoord) -> i32 {
	modifiers := game_get_move_modifier(TileCoord(from), TileCoord(to))
	cost := game_move_modifiers_to_cost(modifiers)
	if .IsFast in entity.meta.flags do cost = i32(f32(cost) * 0.8)
	if .IsSlow in entity.meta.flags do cost = i32(f32(cost) * 1.2)
	return cost
}

// //
// game_calculate_move_cost_djikstra_player :: proc(from: [2]i32, to: [2]i32) -> i32 {
// }

game_calculate_move_cost_djikstra :: proc(from: [2]i32, to: [2]i32) -> i32 {
	modifiers := game_get_move_modifier(TileCoord(from), TileCoord(to))
	cost := game_move_modifiers_to_cost(modifiers)
	if cost < 0 do return cost

	// Add a slight increase to discourage diagonals
	// if math.abs(to.x - from.x) + math.abs(to.y - from.y) > 1 do cost += 10

	// Add cost to avoid this tile
	if .Avoid in modifiers do cost += 50

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
					if .Traversable in tile.flags do return out_coord, true
				}
			}
		}
	}

	return {}, false
}


game_init :: proc() -> Error {
	e_alloc: mem.Allocator_Error

	state.client.game.players, e_alloc = make(
		map[PlayerId]Player,
		8,
		allocator = persistent_arena_alloc,
	)
	if e_alloc != nil do return error(e_alloc)
	state.client.game.entities, e_alloc = make(
		map[EntityId]Entity,
		2048,
		allocator = persistent_arena_alloc,
	)
	if e_alloc != nil do return error(e_alloc)

	derived_init() or_return

	items_init()
	containers_init()

	return nil
}
