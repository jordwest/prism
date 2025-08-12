package main

import "prism"

Tiles :: struct {
	data: [LEVEL_WIDTH * LEVEL_HEIGHT]TileData,
}

TileData :: struct {
	type:  TileType,
	flags: TileFlags,
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
