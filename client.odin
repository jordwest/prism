package main

import "fresnel"
import "prism"

client_tick :: proc(dt: f32) {
    fresnel.clear()
	fresnel.fill(0, 0, 0, 255)
	fresnel.draw_rect(0, 0, f32(state.width), f32(state.height))

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
			v := rand_float_at(u64(x), u64(y)) //rand_f32(hash_data[:])
			sx := 2
			if (v > 0.9) {
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

	fresnel.draw_image(1, 32, 80, 16, 16, f32(state.cursor_pos.x), f32(state.cursor_pos.y), 32, 32)
}

client_send_message :: proc(msg: ClientMessage) {
	m: ClientMessage = msg
	s := prism.create_serializer(frame_arena_alloc)
	client_message_union_serialize(&s, &m)
	fresnel.client_send_message(s.stream[:])
}
