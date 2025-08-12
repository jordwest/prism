package main

import "prism"

// Mark all tiles in visible range as "seen"
vision_update :: proc() {
	for _, p in state.client.game.players {
		entity, ok := entity(p.player_entity_id).?
		if !ok do continue

		// TODO - proper LOS

		iter := prism.AabbIterator(i32) {
			aabb = prism.Aabb(i32) {
				x1 = entity.pos.x - 4,
				y1 = entity.pos.y - 4,
				x2 = entity.pos.x + 4,
				y2 = entity.pos.y + 4,
			},
		}


		for pos in prism.aabb_iterate(&iter) {
			tile, ok := tile_at(TileCoord(pos)).?
			if !ok do continue
			tile.flags = tile.flags + {.Seen}
		}
	}
}
