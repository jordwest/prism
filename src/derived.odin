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
	)
	if e_alloc != nil do return error(e_alloc)

	e_alloc = prism.djikstra_init(&state.client.game.derived.djikstra_algo)
	if e_alloc != nil do return error(e_alloc)

	return nil
}

derived_clear :: proc() {
	trace("Clearing derived data")
	clear(&state.client.game.derived.entity_djikstra_maps)
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

derived_djikstra_map_to :: proc(
	eid: EntityId,
) -> (
	^prism.DjikstraMap(LEVEL_WIDTH, LEVEL_HEIGHT),
	Error,
) {
	maps := &state.client.game.derived.entity_djikstra_maps
	existing_map, has_existing_map := &maps[eid]
	if has_existing_map do return existing_map, nil

	entity, entity_exists := state.client.game.entities[eid]
	if !entity_exists do return nil, error(EntityNotFound{entity_id = eid})

	trace("Regenerating djikstra map for entity %d", eid)

	e: prism.DjikstraError

	trace("Djikstra maps len=%d, cap=%d", len(maps), cap(maps))
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

	e = prism.djikstra_map_generate(algo, game_calculate_move_cost_djikstra)
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
