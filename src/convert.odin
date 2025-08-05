package main

vec2f_from_vec2i :: #force_inline proc(v: [2]i32) -> [2]f32 {
	return {f32(v.x), f32(v.y)}
}
vec2f_from_i32 :: #force_inline proc(v: i32) -> [2]f32 {
	return {f32(v), f32(v)}
}
vec2f_from_tile_coord :: #force_inline proc(v: TileCoord) -> [2]f32 {
	return {f32(v.x), f32(v.y)}
}
vec2f_from_tile_coord_f :: #force_inline proc(v: TileCoordF) -> [2]f32 {
	return v.xy
}

vec2f :: proc {
	vec2f_from_vec2i,
	vec2f_from_i32,
	vec2f_from_tile_coord,
	vec2f_from_tile_coord_f,
}

screen_coord_from_tile_coord :: #force_inline proc(v: TileCoord) -> ScreenCoord {
	screen_center := [2]f32{f32(state.width), f32(state.height)} / 2
	camera_offset := vec2f(v) - state.client.camera.pos

	return ScreenCoord(camera_offset * 16 * state.client.zoom + screen_center)
}

screen_coord_from_tile_coord_f :: #force_inline proc(v: TileCoordF) -> ScreenCoord {
	screen_center := [2]f32{f32(state.width), f32(state.height)} / 2
	camera_offset := vec2f(v.xy) - state.client.camera.pos
	return ScreenCoord(camera_offset * GRID_SIZE * state.client.zoom + screen_center)
}

// screen_coord_from_vec2f :: #force_inline proc(v: [2]f32) -> ScreenCoord {
// 	return ScreenCoord(vec2f(([2]i32)(v)) * GRID_SIZE * state.client.zoom)
// }

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
