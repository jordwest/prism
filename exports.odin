package main

import "core:mem"
import "fresnel"
import clay "clay-odin"

@(export)
boot :: proc(width: i32, height: i32, flags: i32) {
	memory_init()

	context.assertion_failure_proc = on_panic
	context.allocator = persistent_arena_alloc
	context.temp_allocator = frame_arena_alloc

	state.players = make(map[PlayerId]PlayerMeta, 8)

	msg := GameState {
		t        = state.t,
		test     = 28,
		greeting = "lll",
	}

	if (flags == 0) {
		state.is_server = true
	} else {
		msg_data := []u8{8, 3, 1}
		fresnel.client_send_message(msg_data)

		msg_data = {8, 3, 2}
		fresnel.client_send_message(msg_data)
	}

	msg_in: [100]u8
	bytes_read := 0
	for {
		bytes_read := fresnel.client_poll_message(msg_in[:])
		if bytes_read <= 0 {
			break
		}
		trace("Client message received")
		fresnel.log_slice("message in", msg_in[:bytes_read])
	}

	hot_reload_hydrate_state()

	trace("Time is %.2f", state.t)

	// Boot clay
	state.width = width
	state.height = width
	min_memory_size := clay.MinMemorySize()

	if min_memory_size > len(clay_memory) {
		err(
			"Not enough memory reserved for clay. Needed %d bytes, got %d",
			min_memory_size,
			len(clay_memory),
		)
		unreachable()
	}

	clay_arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(
		uint(min_memory_size),
		raw_data(clay_memory[:]),
	)

	clay.Initialize(clay_arena, {f32(width), f32(height)}, {handler = clay_error_handler})

	fresnel.metric_i32("clay max elements", clay.GetMaxElementCount())

	// Tell clay how to measure text
	clay.SetMeasureTextFunction(clay_measure_text, nil)

	clay.SetDebugModeEnabled(CLAY_DEBUG_ENABLED)

	return
}

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


@(export)
on_dev_hot_unload :: proc() {
	szr := create_serializer(frame_arena_alloc)
	result := serialize_state(&szr, &state)
	if result != nil {
		err("Serialization failed! %s at %d", result, szr.offset)
	}

	fresnel.storage_set("dev_state", szr.stream[:])
}
