package main

import "prism"

Entity :: struct {
	id:      EntityId,
	meta_id: EntityMetaId,
	pos:     TileCoord,
}

EntityMeta :: struct {
	spritesheet_coord: [2]i32,
}

TileCoord :: distinct [2]i32

EntityMetaId :: enum {
    Player
}

entity_meta : [EntityMetaId] EntityMeta = {
    .Player = EntityMeta {
        spritesheet_coord = SPRITE_COORD_PLAYER,
    }
}

SPRITE_COORD_PLAYER: [2]i32 = {0, 0}
SPRITE_COORD_ACTIVE_CHEVRON: [2]i32 = {16, 64}

entity_serialize :: proc(
	s: ^prism.Serializer,
	e: ^Entity,
) -> prism.SerializationResult {
	prism.serialize(s, (^i32)(&e.id)) or_return
	prism.serialize(s, (^i32)(&e.meta_id)) or_return
	prism.serialize(s, (^[2]i32)(&e.pos)) or_return
	return nil
}
