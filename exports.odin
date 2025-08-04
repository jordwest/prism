package main

import "core:mem"
import "fresnel"

@(export)
tick :: proc(dt: f32) {
	context.assertion_failure_proc = on_panic
	context.allocator = persistent_arena_alloc
	context.temp_allocator = frame_arena_alloc

	fresnel.clear()
	fresnel.fill(0, 0, 0, 255)
	fresnel.draw_rect(0, 0, f32(state.width), f32(state.height))

	fresnel.metric_i32("persistent mem", i32(persistent_arena.offset))
	fresnel.metric_i32("persistent mem peak", i32(persistent_arena.peak_used))

	state.t += dt

	if state.is_server {
		server_poll()
	}

	if (state.other_pointer_down == 1) {
		fresnel.fill(255, 0, 0, 255)
	} else {
		fresnel.fill(0, 0, 0, 255)
	}

	grid_size := 16
	scale := 2
	view_grid := grid_size * scale

	splitmix_state = SplitMixState{}
	t0 := fresnel.now()
	hash_data: [10]u8 = {34, 54, 77, 124, 12, 45, 0, 221, 123, 139}
	for x := 0; x < 30; x += 1 {
		for y := 0; y < 20; y += 1 {
			hash_data[0] = u8(y)
			hash_data[1] = u8(x)
			hash_data[2] = u8(state.t)
			v := rand_float_at(u64(x) + u64(state.t), u64(y) + u64(state.t)) //rand_f32(hash_data[:])
			sx := 2
			if (v > 0.5) {
				sx = 3
			}
			// text := fmt.tprintf("%.1f", v)
			fresnel.draw_image(
				1,
				f32(sx * 16),
				3 * 16,
				16,
				16,
				f32(x * view_grid),
				f32(y * view_grid),
				f32(view_grid),
				f32(view_grid),
			)
			// fresnel.fill(255, 255, 255, 255)
			// fresnel.draw_text(f32(x * view_grid), f32(y * view_grid), 16, text)
		}
	}
	t1 := fresnel.now()
	fresnel.metric_i32("Tile loop", t1 - t0)

	render_ui()

	fresnel.draw_image(
		1,
		32,
		80,
		16,
		16,
		f32(state.other_pointer_x),
		f32(state.other_pointer_y),
		32,
		32,
	)

	fresnel.metric_i32("temp mem", i32(frame_arena.offset))
	fresnel.metric_i32("temp mem peak", i32(frame_arena.peak_used))
	fresnel.metric_i32("temp mem count", i32(frame_arena.temp_count))
	mem.arena_free_all(&frame_arena)
}
