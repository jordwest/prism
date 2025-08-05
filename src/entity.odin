package main

import "prism"

EntityId :: distinct i32

Entity :: struct {
	id:         EntityId,
	meta_id:    EntityMetaId,
	pos:        TileCoord,
	cmd:        Command,
	player_id:  Maybe(PlayerId),

	// Not serialized
	_local_cmd: Maybe(LocalCommand),
}

LocalCommand :: struct {
	cmd: Command,
	seq: i32,
}

EntityMeta :: struct {
	spritesheet_coord: [2]f32,
	flags:             bit_set[EntityMetaFlags],
}

TileCoord :: distinct [2]i32
TileCoordF :: distinct [2]f32
ScreenCoord :: distinct [2]f32

EntityMetaId :: enum u8 {
	None,
	Player,
}

EntityMetaFlags :: enum {
	IsPlayerControlled,
	IsAllied,
}

entity_meta: [EntityMetaId]EntityMeta = {
	.None = EntityMeta{spritesheet_coord = {0, 0}},
	.Player = EntityMeta {
		spritesheet_coord = SPRITE_COORD_PLAYER,
		flags = {.IsPlayerControlled, .IsAllied},
	},
}

entity_serialize :: proc(s: ^prism.Serializer, e: ^Entity) -> prism.SerializationResult {
	prism.serialize(s, (^i32)(&e.id)) or_return
	prism.serialize(s, (^u8)(&e.meta_id)) or_return
	prism.serialize(s, (^[2]i32)(&e.pos)) or_return
	command_serialize(s, &e.cmd) or_return
	return nil
}

entity_get_command :: proc(e: ^Entity) -> Command {
	if local_cmd, has_local := e._local_cmd.?; has_local {
		return local_cmd.cmd
	}

	return e.cmd
}
