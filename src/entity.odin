package main

Entity :: struct {
	id:   EntityId,
	pos:  TileCoord,
	meta: ^EntityMeta,
}

EntityMeta :: struct {
	spritesheet_coord: [2]i32,
}

TileCoord :: distinct [2]i32

ENTITY_PLAYER := EntityMeta {
	spritesheet_coord = SPRITE_COORD_PLAYER,
}

SPRITE_COORD_PLAYER: [2]i32 = {0, 0}
SPRITE_COORD_ACTIVE_CHEVRON: [2]i32 = {16, 64}

// TODO: This should only run on server and should emit an event
entity_create :: proc(meta: ^EntityMeta) -> ^Entity {
	host_state.newest_entity_id += 1
	id := EntityId(host_state.newest_entity_id)

	state.entities[id] = Entity {
		id   = id,
		meta = meta,
	}

	return &state.entities[id]
}
