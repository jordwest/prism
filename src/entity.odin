package main

import "prism"

EntityId :: distinct i32

Entity :: struct {
	id:            EntityId,
	meta_id:       EntityMetaId,
	pos:           TileCoord,
	cmd:           Command,
	action_points: i32,
	player_id:     Maybe(PlayerId),

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

entity_djikstra_map_to :: proc(
	eid: EntityId,
) -> (
	^prism.DjikstraMap(LEVEL_WIDTH, LEVEL_HEIGHT),
	Error,
) {
	existing_map, has_existing_map := &state.client.game.entity_djikstra_maps[eid]
	if has_existing_map do return existing_map, nil

	entity, entity_exists := state.client.game.entities[eid]
	if !entity_exists do return nil, error(EntityNotFound{entity_id = eid})

	trace("Regenerating djikstra map for entity %d", eid)

	e: prism.DjikstraError

	algo := &state.client.djikstra
	state.client.game.entity_djikstra_maps[eid] = prism.DjikstraMap(LEVEL_WIDTH, LEVEL_HEIGHT){}
	new_map := &state.client.game.entity_djikstra_maps[eid]

	e = prism.djikstra_map_init(new_map, algo)
	if e != nil do return nil, error(e)

	prism.djikstra_map_add_origin(algo, Vec2i(entity.pos))
	if e != nil do return nil, error(e)

	prism.djikstra_map_generate(algo, game_calculate_move_cost)
	if e != nil do return nil, error(e)

	return new_map, nil
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
