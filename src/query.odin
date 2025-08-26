package main

import "prism"

q_obstacle_at :: proc(pos: TileCoord) -> (^Entity, bool) {
	tile, valid_tile := tile_at(pos).?
	if !valid_tile do return nil, false
	if .Obstacle in tile.flags do return nil, true
	tile_entities := derived_entities_at(pos)
	return tile_entities.obstacle.?
}

q_entities_in_range_of :: proc(pos: TileCoord, filter: EntityFilterProc) -> (^Entity, bool) {
	// TODO: Support ranged attacks
	dist_to_check: i32 = 1

	bounds := prism.Aabb(i32) {
		x1 = pos.x - dist_to_check,
		y1 = pos.y - dist_to_check,
		x2 = pos.x + dist_to_check + 1,
		y2 = pos.y + dist_to_check + 1,
	}

	iter := prism.aabb_iterator(bounds)

	for pos in prism.aabb_iterate(&iter) {
		if !prism.aabb_is_edge(iter.aabb, pos) do continue

		entity, has_entity := game_entity_at(TileCoord(pos), filter).?

		if has_entity do return entity, true
	}

	return nil, false
}

q_first_living_player_entity :: proc() -> Maybe(^Entity) {
	for _, &entity in state.client.game.entities {
		if entity.player_id != nil && !entity.despawning {
			return &entity
		}
	}

	return nil
}
