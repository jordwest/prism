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
