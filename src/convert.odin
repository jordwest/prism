package main

vec2f_from_vec2i :: #force_inline proc(v: [2]i32) -> [2]f32 {
	return {f32(v.x), f32(v.y)}
}
vec2f_from_i32 :: #force_inline proc(v: i32) -> [2]f32 {
	return {f32(v), f32(v)}
}

vec2f :: proc {
	vec2f_from_vec2i,
	vec2f_from_i32,
}

screen_coord_from_tile_coord :: #force_inline proc(v: TileCoord) -> ScreenCoord {
	return ScreenCoord(vec2f(([2]i32)(v)) * 16 * state.client.zoom)
}

screen_coord_from_tile_coord_f :: #force_inline proc(v: TileCoordF) -> ScreenCoord {
	return ScreenCoord(v * GRID_SIZE * state.client.zoom)
}

screen_coord_from_vec2f :: #force_inline proc(v: TileCoord) -> ScreenCoord {
	return ScreenCoord(vec2f(([2]i32)(v)) * GRID_SIZE * state.client.zoom)
}

screen_coord :: proc {
	screen_coord_from_tile_coord,
	screen_coord_from_tile_coord_f,
}

tile_coord_from_screen_coord :: #force_inline proc(v: ScreenCoord) -> TileCoord {
	return TileCoord(
		{i32(v.x / (GRID_SIZE * state.client.zoom)), i32(v.y / (GRID_SIZE * state.client.zoom))},
	)
}

tile_coord :: proc {
	tile_coord_from_screen_coord,
}
