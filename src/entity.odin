package main

import "prism"

EntityId :: distinct i32

Entity :: struct {
	id:            EntityId,
	meta_id:       EntityMetaId,
	pos:           TileCoord,
	cmd:           Command,
	flags:         bit_set[EntityFlags],
	action_points: i32,
	player_id:     Maybe(PlayerId),
	spring:        prism.Spring(2),

	// Not serialized
	_local_cmd:    Maybe(LocalCommand),
}

LocalCommand :: struct {
	cmd:     Command,
	cmd_seq: CmdSeqId,
	t:       f32,
}

EntityMeta :: struct {
	spritesheet_coord: [2]f32,
	flags:             bit_set[EntityFlags],
}

TileCoord :: distinct [2]i32
TileCoordF :: distinct [2]f32
ScreenCoord :: distinct [2]f32

EntityMetaId :: enum u8 {
	None,
	Player,
}

EntityFlags :: enum {
	IsPlayerControlled,
	IsAllied,
	IsObstacle,
	CanMove,
	CanSwapPlaces,
}

entity_meta: [EntityMetaId]EntityMeta = {
	.None = EntityMeta{spritesheet_coord = {0, 0}},
	.Player = EntityMeta {
		spritesheet_coord = SPRITE_COORD_PLAYER,
		flags = {.IsPlayerControlled, .IsAllied, .IsObstacle, .CanMove, .CanSwapPlaces},
	},
}

entity_is_obstacle :: proc(entity: ^Entity) -> bool {
	return .IsObstacle in entity.flags
}

entity_set_pos :: proc(entity: ^Entity, pos: TileCoord) {
	entity.pos = pos
	derived_clear()
}

entity_swap_pos :: proc(a: ^Entity, b: ^Entity) {
	pos_a := b.pos
	pos_b := a.pos

	entity_set_pos(a, pos_a)
	entity_set_pos(b, pos_b)
}

entity_clear_cmd :: proc(entity: ^Entity) {
	entity.cmd = Command{}
	entity._local_cmd = nil
}

entity_consume_ap :: proc(entity: ^Entity, ap: i32) {
	entity.action_points -= ap
}

entity_add_ap :: proc(entity: ^Entity, ap: i32 = 100) {
	entity.action_points += ap
}

entity_id_serialize :: proc(s: ^prism.Serializer, eid: ^EntityId) -> prism.SerializationResult {
	return prism.serialize_i32(s, (^i32)(eid))
}

entity_serialize :: proc(s: ^prism.Serializer, e: ^Entity) -> prism.SerializationResult {
	serialize(s, (^i32)(&e.id)) or_return
	serialize(s, (^u8)(&e.meta_id)) or_return
	serialize(s, (^[2]i32)(&e.pos)) or_return
	serialize(s, (^i32)(&e.player_id)) or_return
	serialize(s, &e.cmd) or_return
	return nil
}

entity_get_command :: proc(e: ^Entity, ignore_new := false) -> Command {
	if local_cmd, has_local := e._local_cmd.?; has_local {
		// Don't show local command until we've given the server a chance to respond.
		// Stops the flashing on low latency connections
		if ignore_new && state.t - local_cmd.t < 0.1 do return e.cmd

		return local_cmd.cmd
	}

	return e.cmd
}
