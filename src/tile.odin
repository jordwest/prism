package main

Tiles :: struct($Width: int, $Height: int) {
	data: [Width * Height]TileData,
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

tile_flags_for :: proc(tile_type: TileType) -> TileFlags {
	switch tile_type {
    	case .Empty: return {}
    	case .Floor: return {.Traversable}
    	case .BrickWall: return {.Obstacle}
    	case .RopeBridge: return {.Traversable, .Obstacle}
	}

	return {}
}
