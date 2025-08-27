package main

import "prism"

// Mark all tiles in visible range as "seen"
vision_update :: proc() {

	for &tile in state.client.game.tiles.data {
		// Clear visibile tiles as they'll be set in next loop
		tile.flags -= {.Visible}
	}

	for _, p in state.client.game.players {
		entity, ok := entity(p.player_entity_id).?
		if !ok do continue

		// TODO - proper LOS

		iter := prism.aabb_iterator(
			prism.Aabb(i32) {
				x1 = entity.pos.x - entity.meta.vision_distance,
				y1 = entity.pos.y - entity.meta.vision_distance,
				x2 = entity.pos.x + entity.meta.vision_distance + 1,
				y2 = entity.pos.y + entity.meta.vision_distance + 1,
			},
		)


		for pos in prism.aabb_iterate(&iter) {
			tile, ok := tile_at(TileCoord(pos)).?
			if !ok do continue
			tile.flags = tile.flags + {.Seen, .Visible}
		}
	}

	for _, &entity in state.client.game.entities {
		tile, ok := tile_at(entity.pos).?
		if !ok do continue
		if .IsVisibleToPlayers in entity.meta.flags && .Visible not_in tile.flags {
			entity.meta.flags -= {.IsVisibleToPlayers}
			event_fire(EventEntityVisibilityChanged{entity_id = entity.id, visible = false})
		} else if .IsVisibleToPlayers not_in entity.meta.flags && .Visible in tile.flags {
			entity.meta.flags += {.IsVisibleToPlayers}
			event_fire(EventEntityVisibilityChanged{entity_id = entity.id, visible = true})
		}
	}
}
