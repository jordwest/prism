package main

import "prism"

EntityId :: distinct i32

Entity :: struct {
	id:            EntityId,
	meta:          EntityMeta,
	pos:           TileCoord,
	cmd:           Command,
	action_points: i32,
	hp:            i32,
	player_id:     Maybe(PlayerId),
	spring:        prism.Spring(2),
	despawning:    bool,

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
	max_hp:            i32,
	team:              Team,
	flags:             bit_set[EntityFlags],
}

TileCoord :: prism.TileCoord
TileCoordF :: prism.TileCoordF
ScreenCoord :: distinct [2]f32

Team :: enum {
	Neutral,
	Players,
	Darkness,
}

EntityMetaId :: enum u8 {
	None,
	Player,
	Spider,
	Corpse,
}

EntityFlags :: enum {
	IsPlayerControlled,
	IsObstacle,
	CanMove,
	CanSwapPlaces,
}

entity :: proc(id: EntityId) -> Maybe(^Entity) {
	return &state.client.game.entities[id]
}

entity_meta: [EntityMetaId]EntityMeta = {
	.None = EntityMeta{spritesheet_coord = {0, 0}},
	.Player = EntityMeta {
		spritesheet_coord = SPRITE_COORD_PLAYER,
		team = .Players,
		max_hp = 50,
		flags = {.IsPlayerControlled, .IsObstacle, .CanMove, .CanSwapPlaces},
	},
	.Spider = EntityMeta {
		spritesheet_coord = SPRITE_COORD_SPIDER,
		team = .Darkness,
		max_hp = 7,
		flags = {.IsObstacle, .CanMove},
	},
	.Corpse = EntityMeta{spritesheet_coord = SPRITE_COORD_CORPSE, flags = {}},
}

entity_despawn :: proc(e: ^Entity) {
	e.despawning = true
}

Alignment :: enum {
	Neutral,
	Enemy,
	Friendly,
}

entity_system :: proc(dt: f32) {
	for _, &e in &state.client.game.entities {
		if e.spring.k == 0 {
			e.spring = prism.spring_create(2, vec2f(e.pos), 1500, 1, 120)
		}

		e.spring.target = vec2f(e.pos)

		prism.spring_tick(&e.spring, dt)

		if e.despawning {
			delete_key(&state.client.game.entities, e.id)
		}
	}
}

entity_is_obstacle :: proc(entity: ^Entity) -> bool {
	return .IsObstacle in entity.meta.flags
}

entity_set_pos :: proc(entity: ^Entity, pos: TileCoord) {
	entity.pos = pos
	derived_clear()
}

entity_alignment :: proc(this: ^Entity, other: ^Entity) -> Alignment {
	if this.meta.team == .Neutral || other.meta.team == .Neutral do return .Neutral

	return this.meta.team == other.meta.team ? .Friendly : .Enemy
}

entity_alignment_to_player :: proc(other: ^Entity) -> Alignment {
	player, has_player := player_entity().?
	if !has_player do return .Neutral

	if player.meta.team == .Neutral || other.meta.team == .Neutral do return .Neutral

	return player.meta.team == other.meta.team ? .Friendly : .Enemy
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

// entity_serialize :: proc(s: ^prism.Serializer, e: ^Entity) -> prism.SerializationResult {
// 	serialize(s, (^i32)(&e.id)) or_return
// 	serialize(s, (^u8)(&e.meta_id)) or_return
// 	serialize(s, (^[2]i32)(&e.pos)) or_return
// 	serialize(s, (^i32)(&e.player_id)) or_return
// 	serialize(s, &e.cmd) or_return
// 	return nil
// }

entity_get_command :: proc(e: ^Entity, ignore_new := false) -> Command {
	if local_cmd, has_local := e._local_cmd.?; has_local {
		// Don't show local command until we've given the server a chance to respond.
		// Stops the flashing on low latency connections
		if ignore_new && state.t - local_cmd.t < 0.1 do return e.cmd

		return local_cmd.cmd
	}

	return e.cmd
}
