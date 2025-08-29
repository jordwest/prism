package main

import "core:container/small_array"
import "core:math/fixed"
import "prism"

EntityId :: distinct i32

Entity :: struct {
	id:             EntityId,
	meta_id:        EntityMetaId,
	meta:           EntityMeta,
	pos:            TileCoord,
	cmd:            Command,
	action_points:  i32,
	hp:             i32,
	player_id:      Maybe(PlayerId),
	spring:         prism.Spring(2),
	despawning:     bool,
	ai:             AiBrain,
	move_seq:       i32,
	t_last_hurt:    f32,
	status_effects: EffectList,

	// Not serialized
	_local_cmd:     Maybe(LocalCommand),
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
	vision_distance:   i32,
	abilities:         [4]Ability,
	flavor_text:       string,
	base_action_cost:  i32, // Higher is slower (units of time to take an action - ie 100 is one second)
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
	Gnome,
	Broodmother,
	Firebug,
	Corpse,
}

EntityFlags :: enum {
	IsPlayerControlled,
	IsAiControlled,
	IsObstacle,
	CanSwapPlaces,
	MovedThisTurn,
	MovedLastTurn,
	CanTakeDamage,
	IsVisibleToPlayers,
}

Ability :: struct {
	type:     AbilityType,
	cooldown: i16,
}

AbilityType :: enum {
	EmptySlot,
	Attack,
	Brood,
}

EntityFilterProc :: proc(_: ^Entity) -> bool

entity :: proc(id: EntityId) -> Maybe(^Entity) {
	return &state.client.game.entities[id]
}

entity_or_error :: proc(id: EntityId) -> (^Entity, Error) {
	e, ok := &state.client.game.entities[id]
	if !ok do return nil, error(EntityNotFound{entity_id = id})
	return e, nil
}

entity_find :: proc(filter_info: EntityFilter) -> Maybe(^Entity) {
	for _, &e in state.client.game.entities {
		if filter(filter_info, &e) do return &e
	}
	return nil
}

entity_meta: [EntityMetaId]EntityMeta = {
	.None = EntityMeta{spritesheet_coord = {0, 0}},
	.Player = EntityMeta {
		spritesheet_coord = SPRITE_COORD_PLAYER,
		team = .Players,
		max_hp = 50,
		vision_distance = 6,
		flags = {.IsPlayerControlled, .IsObstacle, .CanSwapPlaces, .CanTakeDamage},
		abilities = {{type = .Attack}, {}, {}, {}},
		flavor_text = "I should've stayed on the surface...",
		base_action_cost = 100,
	},
	.Spider = EntityMeta {
		spritesheet_coord = SPRITE_COORD_SPIDER,
		team = .Darkness,
		max_hp = 5,
		vision_distance = 8,
		flags = {.IsAiControlled, .IsObstacle, .CanTakeDamage},
		abilities = {{type = .Attack}, {}, {}, {}},
		flavor_text = "3 feet tall with thick, black scaled legs - this is no ordinary house spider. It may be weak, but it moves quickly and can easily outrun you.",
		base_action_cost = 80,
	},
	.Gnome = EntityMeta {
		spritesheet_coord = SPRITE_COORD_GNOME,
		team = .Darkness,
		max_hp = 5,
		vision_distance = 8,
		flags = {.IsAiControlled, .IsObstacle, .CanTakeDamage},
		abilities = {{type = .Attack}, {}, {}, {}},
		flavor_text = "The small gnome doesn't look like much of a threat, but for some reason appears disgruntled at your presence.",
		base_action_cost = 100,
	},
	.Firebug = EntityMeta {
		spritesheet_coord = SPRITE_COORD_FIREBUG,
		team = .Darkness,
		max_hp = 12,
		vision_distance = 4,
		flags = {.IsAiControlled, .IsObstacle, .CanTakeDamage},
		abilities = {{type = .Attack}, {}, {}, {}},
		flavor_text = "You'd have mistaken it for a giant cockroach if not for the enormous, glowing red pustule this creature seems to be dragging around on its back. The sack of glowing liquid seems to make it difficult to move.",
		base_action_cost = 120,
	},
	.Broodmother = EntityMeta {
		spritesheet_coord = SPRITE_COORD_BROODMOTHER,
		team = .Darkness,
		max_hp = 20,
		vision_distance = 8,
		flags = {.IsAiControlled, .IsObstacle, .CanTakeDamage},
		abilities = {{type = .Brood}, {}, {}, {}},
		flavor_text = "The towering broodmother hisses and stares at you with all 8 eyes. Below her abdomen she carries a sack that seems to be writhing and pulsating, as if there's something alive in there.",
		base_action_cost = 110,
	},
	.Corpse = EntityMeta{spritesheet_coord = SPRITE_COORD_CORPSE, flags = {}},
}

entity_despawn :: proc(e: ^Entity) {
	e.despawning = true
	derived_handle_entity_changed(e)
	delete_key(&state.client.game.entities, e.id)
}

Alignment :: enum {
	Neutral,
	Enemy,
	Friendly,
}

entity_frame :: proc(dt: f32) {
	for _, &e in &state.client.game.entities {
		if e.spring.k == 0 {
			e.spring = prism.spring_create(
				2,
				vec2f(e.pos),
				ENTITY_SPRING_CONSTANT,
				1,
				ENTITY_SPRING_DAMPER,
			)
		}

		e.spring.target = vec2f(e.pos)

		prism.spring_tick(&e.spring, dt, !SPRINGS_ENABLED)
	}
}

entity_has_ability :: proc(entity: ^Entity, type: AbilityType) -> Maybe(^Ability) {
	for &a in entity.meta.abilities {
		if a.type == type do return &a
	}
	return nil
}

entity_turn :: proc(entity: ^Entity) {
	effect_turn(&entity.status_effects)

	for &ability in entity.meta.abilities {
		if ability.cooldown > 0 do ability.cooldown -= 1
	}
}

entity_set_pos :: proc(entity: ^Entity, pos: TileCoord) {
	event_fire(EventEntityMove{entity_id = entity.id, pos = pos})
}

entity_is_current_player :: proc(e: ^Entity) -> bool {
	if e.player_id == nil do return false
	if state.client.player_id == 0 do return false
	return e.player_id == state.client.player_id
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

entity_clear_cmd :: proc(entity: ^Entity, clear_local := false) {
	entity.cmd = Command{}
	if clear_local do entity._local_cmd = nil
}

// modified_ap: fixed.Fixed16_16
// fixed.init_from_parts(&modified_ap, ap, 0)
// fixed.mul()

// Consumes action points, applying any entity effects
entity_consume_ap :: proc(entity: ^Entity, multiplier := Percent(100)) {
	mult := multiplier

	if .Active in entity.status_effects[.Slowed].flags do mult += Percent(100)

	ap := prism.pct_mul_i32(mult, entity.meta.base_action_cost)
	entity.action_points -= ap
	entity.move_seq += 1
}

entity_add_ap :: proc(entity: ^Entity, ap: i32 = 100) {
	entity.action_points += ap
	if entity.action_points > 100 {
		err("Entity %d has %d AP", entity.id, entity.action_points)
	}
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
