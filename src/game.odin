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
