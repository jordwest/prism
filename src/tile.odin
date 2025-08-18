package main

import "core:math/ease"
import "core:math/linalg"
import "prism"

Tiles :: struct {
	data: [LEVEL_WIDTH * LEVEL_HEIGHT]TileData,
}

TileData :: struct {
	type:  TileType,
	flags: TileFlags,
	fire:  TileFire,
}

TileType :: enum u8 {
	Empty = 0,
	Floor,
	BrickWall,
	RopeBridge,
	Water,
}

TileFlag :: enum {
	Traversable,
	Obstacle,
	Flammable,
	Grass,
	Slow,
	Seen,
}
TileFlags :: bit_set[TileFlag]

tile_default_flags: [TileType]TileFlags = {
	.Empty      = {},
	.Floor      = {.Traversable},
	.BrickWall  = {.Obstacle},
	.RopeBridge = {.Traversable, .Flammable},
	.Water      = {.Traversable, .Slow},
}

TileFire :: struct {
	fuel:     i32, // How many turns worth of fuel is left in this tile
	ignition: bool,
}

tile_set_type :: proc(tile: ^TileData, type: TileType) {
	tile.type = type
	tile.flags = tile_default_flags[type]
}

tile_at :: proc(tile: TileCoord) -> Maybe(^TileData) {
	tiles := &state.client.game.tiles
	if tile.x < 0 || tile.y < 0 do return nil
	if tile.x >= LEVEL_WIDTH do return nil
	if tile.y >= LEVEL_WIDTH do return nil

	idx := tile.x + tile.y * LEVEL_WIDTH
	if idx >= len(tiles.data) do return nil

	return &tiles.data[idx]
}

tile_draw_door :: proc(pos: TileCoord) {
	tile, ok := tile_at(pos).?
	if ok {
		tile_set_type(tile, .Floor)
	}
}

tile_draw :: proc(pos: TileCoord, type: TileType) {
	tile, ok := tile_at(pos).?
	if ok {
		tile_set_type(tile, type)
	}
}

tile_create_fireball :: proc(at: TileCoord, radius: f32, fuel: i32) {
	r := i32(radius)
	iter := prism.aabb_iterator(prism.aabb(Vec2i(at) - {r, r}, Vec2i({r * 2 + 1, r * 2 + 1})))
	for pos in prism.aabb_iterate(&iter) {
		tile, valid_tile := tile_at(TileCoord(pos)).?

		dist := linalg.length(vec2f(pos) - vec2f(at))
		relative_dist := 1 - (dist / radius)
		fuel_ease := ease.quadratic_out(relative_dist)

		if valid_tile && dist <= radius do tile_set_fire(tile, i32(f32(fuel) * fuel_ease))
	}
}

tile_set_fire :: proc(tile: ^TileData, fuel: i32) {
	if tile.type == .Empty do return
	if tile.fire.fuel > 0 do return // Already on fire
	tile.fire.ignition = true // Ignited this turn
	if .Obstacle in tile.flags do return
	if .Flammable in tile.flags do tile.fire.fuel += 6
	if .Grass in tile.flags do tile.fire.fuel += 4
	tile.fire.fuel += fuel
}

tile_handle_turn :: proc() {
	state.client.audio.ambience = {}

	for &tile, i in &state.client.game.tiles.data {
		pos := TileCoord{i32(i) % LEVEL_WIDTH, i32(i) / LEVEL_WIDTH}
		just_ignited := tile.fire.ignition
		tile.fire.ignition = false

		if tile.fire.fuel > 0 {
			tile.fire.fuel -= 1

			// Consumed all fuel
			if tile.fire.fuel == 0 {
				if tile.type == .RopeBridge do tile_set_type(&tile, .Empty)
				if .Grass in tile.flags do tile.flags -= {.Grass}
			}

			// Still burning
			if tile.fire.fuel > 0 {
				state.client.audio.ambience += {.Fire}

				// Spread fire
				iter := prism.aabb_iterator(prism.aabb(Vec2i(pos) - {1, 1}, Vec2i({3, 3})))
				for pos in prism.aabb_iterate(&iter) {
					neighbour, valid_tile := tile_at(TileCoord(pos)).?
					is_flammable := .Flammable in neighbour.flags || .Grass in neighbour.flags
					if !prism.aabb_is_edge(iter.aabb, pos) do continue
					if !valid_tile do continue
					if is_flammable && !just_ignited && neighbour.fire.fuel == 0 do tile_set_fire(neighbour, 0)
				}
			}
		}
	}
}

tile_draw_room :: proc(pos: TileCoord, size: Vec2i) {
	for ox: i32 = 0; ox < size.x; ox += 1 {
		for oy: i32 = 0; oy < size.y; oy += 1 {
			is_boundary := ox == 0 || oy == 0 || ox == size.x - 1 || oy == size.y - 1
			coord := TileCoord({pos.x + ox, pos.y + oy})

			tile, ok := tile_at(coord).?
			if ok {
				tile_set_type(tile, is_boundary ? .BrickWall : .Floor)
				if !is_boundary &&
				   coord.y >= 13 &&
				   coord.y <= 15 &&
				   coord.x >= 15 &&
				   coord.x <= 22 {
					tile_set_type(tile, .Water)
				}
				if !is_boundary && coord.x == 18 && coord.y == 18 {
					tile_set_type(tile, .Water)
				}
			}
		}
	}
}

tile_draw_outline :: proc(aabb: prism.Aabb(i32), type: TileType = .BrickWall) {
	iter := prism.aabb_iterator(aabb)
	for pos in prism.aabb_iterate(&iter) {
		tile, ok := tile_at(TileCoord(pos)).?
		if !ok do continue
		if prism.aabb_is_edge(aabb, pos) do tile_set_type(tile, type)
	}
}

tile_draw_fill :: proc(aabb: prism.Aabb(i32), type: TileType = .Floor) {
	iter := prism.aabb_iterator(aabb)
	for pos in prism.aabb_iterate(&iter) {
		tile, ok := tile_at(TileCoord(pos)).?
		if !ok do continue
		tile_set_type(tile, type)
	}
}

tile_connect_region :: proc(
	start: TileCoord,
	region: prism.Aabb(i32),
	type: TileType = .Floor,
	y_first := false,
) {
	current := start

	for {
		tile_draw(current, .RopeBridge)
		if y_first {
			if current.y >= region.y2 {
				current.y -= 1
				continue
			}
			if current.y < region.y1 {
				current.y += 1
				continue
			}
		}
		if current.x >= region.x2 {
			current.x -= 1
			continue
		}
		if current.x < region.x1 {
			current.x += 1
			continue
		}
		if current.y >= region.y2 {
			current.y -= 1
			continue
		}
		if current.y < region.y1 {
			current.y += 1
			continue
		}
		break
	}
}
