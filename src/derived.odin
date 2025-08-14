package main

import "core:mem"
import "prism"

DerivedDataState :: enum {
	Empty,
	Ready,
}

// Derived state stores data that is derived from the current game state.
// It gets flushed away when a meaningful state changes (an entity moves etc)
// Accessors calculate stuff on demand
DerivedState :: struct {
	tile_entities:        [LEVEL_WIDTH][LEVEL_HEIGHT]TileEntities,
	s_tile_entities:      DerivedDataState,
	entity_djikstra_maps: map[EntityId]prism.DjikstraMap(LEVEL_WIDTH, LEVEL_HEIGHT),
	allies_djikstra_map:  Maybe(prism.DjikstraMap(LEVEL_WIDTH, LEVEL_HEIGHT)),

	// Not flushed
	djikstra_algo:        prism.DjikstraAlgo(LEVEL_WIDTH, LEVEL_HEIGHT),
}

TileEntities :: struct {
	obstacle: Maybe(^Entity),
	ground:   Maybe(^Entity),
	// TODO: Flags here to indicate whether there are multiple objects on the ground?
}

derived_init :: proc() -> Error {
	e_alloc: mem.Allocator_Error

	state.client.game.derived.entity_djikstra_maps, e_alloc = make(
		map[EntityId]prism.DjikstraMap(LEVEL_WIDTH, LEVEL_HEIGHT),
		MAX_PLAYERS,
		allocator = persistent_arena_alloc,
	)
	if e_alloc != nil do return error(e_alloc)

	e_alloc = prism.djikstra_init(&state.client.game.derived.djikstra_algo)
	if e_alloc != nil do return error(e_alloc)

	return nil
}

derived_handle_entity_changed :: proc(entity: ^Entity) {
	delete_key(&state.client.game.derived.entity_djikstra_maps, entity.id)
	if entity.meta.team == .Players {
		vision_update()
		state.client.game.derived.allies_djikstra_map = nil
		derived_djikstra_map_to(entity.id)
	}

	if .MovedLastTurn not_in entity.meta.flags {
		derived_regenerate_player_maps()
	}
	state.client.game.derived.s_tile_entities = .Empty
}

derived_regenerate_player_maps :: proc() {
	clear(&state.client.game.derived.entity_djikstra_maps)
	for _, player in state.client.game.players {
		trace("Regenerate djikstra map to ", player.player_entity_id)
		_, e := derived_djikstra_map_to(player.player_entity_id)
		if e != nil do error_log(e)
	}
}

derived_clear :: proc() {
	clear(&state.client.game.derived.entity_djikstra_maps)
	for _, player in state.client.game.players {
		derived_djikstra_map_to(player.player_entity_id)
	}
	state.client.game.derived.s_tile_entities = .Empty
}

derived_entities_at :: proc(coord: TileCoord, ignore_out_of_bounds := false) -> TileEntities {
	derived := &state.client.game.derived
	if derived.s_tile_entities == .Empty do _derive_tile_entities()

	if coord.x < 0 || coord.x >= LEVEL_WIDTH || coord.y < 0 || coord.y >= LEVEL_HEIGHT {
		if !ignore_out_of_bounds do warn("Attempt to access tile entities outside bounds")
		return TileEntities{}
	}

	return derived.tile_entities[coord.x][coord.y]
}

derived_allies_djikstra_map :: proc(
	dont_generate := false,
) -> (
	^prism.DjikstraMap(LEVEL_WIDTH, LEVEL_HEIGHT),
	Error,
) {
	dmap, has_existing_map := &state.client.game.derived.allies_djikstra_map.?
	if has_existing_map do return dmap, nil

	state.client.game.derived.allies_djikstra_map = prism.DjikstraMap(LEVEL_WIDTH, LEVEL_HEIGHT){}
	dmap = &state.client.game.derived.allies_djikstra_map.?

	e: prism.DjikstraError

	algo := &state.client.game.derived.djikstra_algo

	e = prism.djikstra_map_init(dmap, algo)
	if e != nil do return nil, error(e)

	for _, entity in state.client.game.entities {
		if entity.meta.team != .Players do continue

		e = prism.djikstra_map_add_origin(algo, Vec2i(entity.pos))
		if e != nil do return nil, error(e)
	}

	e = prism.djikstra_map_generate(algo, game_calculate_move_cost_djikstra)
	if e != nil do return nil, error(e)

	return dmap, nil
}

derived_djikstra_map_to :: proc(
	eid: EntityId,
	dont_generate: bool = false,
) -> (
	^prism.DjikstraMap(LEVEL_WIDTH, LEVEL_HEIGHT),
	Error,
) {
	maps := &state.client.game.derived.entity_djikstra_maps
	existing_map, has_existing_map := &maps[eid]
	if has_existing_map do return existing_map, nil

	if dont_generate do return {}, nil

	entity, entity_exists := state.client.game.entities[eid]
	if !entity_exists do return nil, error(EntityNotFound{entity_id = eid})

	e: prism.DjikstraError

	algo := &state.client.game.derived.djikstra_algo
	if len(maps) == cap(maps) {
		return nil, error(.Out_Of_Memory)
	}

	maps[eid] = prism.DjikstraMap(LEVEL_WIDTH, LEVEL_HEIGHT){}
	new_map := &state.client.game.derived.entity_djikstra_maps[eid]

	e = prism.djikstra_map_init(new_map, algo)
	if e != nil do return nil, error(e)

	e = prism.djikstra_map_add_origin(algo, Vec2i(entity.pos))
	if e != nil do return nil, error(e)

	e = prism.djikstra_map_generate(
	algo,
	proc(from: [2]i32, to: [2]i32) -> i32 {
		modifiers := game_get_move_modifier(TileCoord(from), TileCoord(to))
		cost := game_move_modifiers_to_cost(modifiers)
		if cost < 0 do return cost

		when !FOG_OF_WAR_OFF {
			if .Unseen in modifiers do return -1
		}

		// Add cost to avoid this tile
		if .Avoid in modifiers do cost += 50

		return cost
	},
	)
	if e != nil do return nil, error(e)

	return new_map, nil
}

@(private = "file")
_derive_tile_entities :: proc() {
	derived := &state.client.game.derived
	mem.zero_slice(derived.tile_entities[:])

	for _, &e in state.client.game.entities {
		if .IsObstacle in e.meta.flags {
			derived.tile_entities[e.pos.x][e.pos.y].obstacle = &e
		} else {
			derived.tile_entities[e.pos.x][e.pos.y].ground = &e
		}
	}

	derived.s_tile_entities = .Ready
}
