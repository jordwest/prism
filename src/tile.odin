package main

import "prism"

Tiles :: struct {
	data: [LEVEL_WIDTH * LEVEL_HEIGHT]TileData,
}

TileData :: struct {
	type: TileType,
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
}
TileFlags :: bit_set[TileFlag]

tile_flags: [TileType]TileFlags = {
	.Empty      = {},
	.Floor      = {.Traversable},
	.BrickWall  = {.Obstacle},
	.RopeBridge = {.Traversable, .Flammable},
	.Water      = {.Traversable, .Slow},
}

tile_at :: proc(tiles: ^Tiles, tile: TileCoord) -> Maybe(^TileData) {
	if tile.x < 0 || tile.y < 0 do return nil

	idx := tile.x + tile.y * LEVEL_WIDTH
	if idx >= len(tiles.data) do return nil

	return &tiles.data[idx]
}

tile_draw_door :: proc(pos: TileCoord) {
	tile, ok := tile_at(&state.client.game.tiles, pos).?
	if ok {
		tile.type = .Floor
	}
}

tile_draw :: proc(pos: TileCoord, type: TileType) {
	tile, ok := tile_at(&state.client.game.tiles, pos).?
	if ok {
		tile.type = type
	}
}

tile_draw_room :: proc(pos: TileCoord, size: Vec2i) {
	for ox: i32 = 0; ox < size.x; ox += 1 {
		for oy: i32 = 0; oy < size.y; oy += 1 {
			is_boundary := ox == 0 || oy == 0 || ox == size.x - 1 || oy == size.y - 1
			coord := TileCoord({pos.x + ox, pos.y + oy})

			tile, ok := tile_at(&state.client.game.tiles, coord).?
			if ok {
				tile.type = is_boundary ? .BrickWall : .Floor
				if !is_boundary &&
				   coord.y >= 13 &&
				   coord.y <= 15 &&
				   coord.x >= 15 &&
				   coord.x <= 22 {
					tile.type = .Water
				}
				if !is_boundary && coord.x == 18 && coord.y == 18 {
					tile.type = .Water
				}
			}
		}
	}
}

tiles_serialize :: proc(s: ^prism.Serializer, tiles: ^Tiles) -> prism.SerializationResult {
	prism.serialize_slice(s, tiles.data[:], _tile_data_serialize) or_return
	return nil
}

@(private = "file")
_tile_data_serialize :: proc(s: ^prism.Serializer, tiles: ^TileData) -> prism.SerializationResult {
	serialize(s, (^u8)(&tiles.type))
	return nil
}
