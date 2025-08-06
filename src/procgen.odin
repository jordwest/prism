package main

import "fresnel"

@(private = "file")
Room :: struct {
	pos:  TileCoord,
	size: Vec2i,
}

procgen_generate_level :: proc(seed: u64) {
	trace("Start procgen")
	t0 := fresnel.now()

	tile_draw_room(TileCoord({1, 1}), Vec2i({8, 16}))

	t1 := fresnel.now()
	trace("Procgen took %dms", t1 - t0)
}
