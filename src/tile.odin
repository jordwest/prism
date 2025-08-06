package main

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
}

TileFlag :: enum {
	Traversable,
	Obstacle,
	Flammable,
}
TileFlags :: bit_set[TileFlag]

tile_flags: [TileType]TileFlags = {
	.Empty      = {},
	.Floor      = {.Traversable},
	.BrickWall  = {.Obstacle},
	.RopeBridge = {.Traversable, .Flammable},
}

tile_at :: proc(tiles: ^Tiles, tile: TileCoord) -> Maybe(^TileData) {
	if tile.x < 0 || tile.y < 0 do return nil

	idx := tile.x + tile.y * LEVEL_WIDTH
	if idx >= len(tiles.data) do return nil

	return &tiles.data[idx]
}

tile_draw_door :: proc(pos: TileCoord) {
	tile, ok := tile_at(&state.host.shared.tiles, pos).?
	if ok {
		tile.type = .Floor
	}
}

tile_draw_room :: proc(pos: TileCoord, size: Vec2i) {
	for ox: i32 = 0; ox < size.x; ox += 1 {
		for oy: i32 = 0; oy < size.y; oy += 1 {
			is_boundary := ox == 0 || oy == 0 || ox == size.x - 1 || oy == size.y - 1

			coord := TileCoord({pos.x + ox, pos.y + oy})
			tile, ok := tile_at(&state.host.shared.tiles, coord).?
			if ok {
				tile.type = is_boundary ? .BrickWall : .Floor
			}
		}
	}
}
