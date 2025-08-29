package main

import "prism"

q_obstacle_at :: proc(pos: TileCoord) -> (^Entity, bool) {
	tile, valid_tile := tile_at(pos).?
	if !valid_tile do return nil, false
	if .Obstacle in tile.flags do return nil, true
	tile_entities := derived_entities_at(pos)
	return tile_entities.obstacle.?
}

q_entities_in_range_of_ability :: proc(
	pos: TileCoord,
	filter: EntityFilterProc,
	ability: ^Ability,
) -> (
	^Entity,
	bool,
) {
	distance: i32 = 0
	switch ability.type {
	case .Attack:
		distance = 1
	case .Brood:
		distance = 12
	case .EmptySlot:
		distance = 0
	}

	return q_entities_in_range_of(pos, filter, distance)
}

q_entities_in_range_of :: proc(
	pos: TileCoord,
	filter: EntityFilterProc,
	max_distance: i32 = 1,
) -> (
	^Entity,
	bool,
) {
	for distance: i32 = 1; distance <= max_distance; distance += 1 {
		bounds := prism.Aabb(i32) {
			x1 = pos.x - distance,
			y1 = pos.y - distance,
			x2 = pos.x + distance + 1,
			y2 = pos.y + distance + 1,
		}

		iter := prism.aabb_iterator(bounds)

		for pos in prism.aabb_iterate(&iter) {
			if !prism.aabb_is_edge(iter.aabb, pos) do continue

			entity, has_entity := game_entity_at(TileCoord(pos), filter).?

			if has_entity do return entity, true
		}
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
