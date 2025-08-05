package main

import "prism"

EntityId :: distinct i32

Entity :: struct {
	id:         EntityId,
	meta_id:    EntityMetaId,
	pos:        TileCoord,
	cmd:        Command,

	// Not serialized
	_local_cmd: Maybe(Command),
}

EntityMeta :: struct {
	spritesheet_coord: [2]f32,
}

TileCoord :: distinct [2]i32
TileCoordF :: distinct [2]f32
ScreenCoord :: distinct [2]f32

EntityMetaId :: enum u8 {
	None,
	Player,
}

entity_meta: [EntityMetaId]EntityMeta = {
	.None = EntityMeta{spritesheet_coord = {0, 0}},
	.Player = EntityMeta{spritesheet_coord = SPRITE_COORD_PLAYER},
}

entity_serialize :: proc(s: ^prism.Serializer, e: ^Entity) -> prism.SerializationResult {
	prism.serialize(s, (^i32)(&e.id)) or_return
	prism.serialize(s, (^u8)(&e.meta_id)) or_return
	prism.serialize(s, (^[2]i32)(&e.pos)) or_return
	command_serialize(s, &e.cmd) or_return
	return nil
}
