package main

// Assign a new entity ID and return it (does not yet spawn it, it doesn't live anywhere except on the stack!)
game_spawn_entity :: proc(entity: Entity) -> ^Entity {
	state.client.game.newest_entity_id += 1
	id := EntityId(state.client.game.newest_entity_id)

	state.client.game.entities[id] = entity
	new_entity := &state.client.game.entities[id]

	new_entity.id = id

	return new_entity
}

game_calculate_move_cost :: proc(_from: [2]i32, to: [2]i32) -> i32 {
	tile, valid_tile := tile_at(&state.client.game.tiles, TileCoord(to)).?
	if !valid_tile do return -1
	if .Traversable not_in tile_flags[tile.type] do return -1
	if .Slow in tile_flags[tile.type] do return 2
	return 1
}
