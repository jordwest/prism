package main

import "base:runtime"
import clay "clay-odin"
import "core:mem"
import "fresnel"
import "prism"

@(export)
on_resize :: proc(w: i32, h: i32) {
	state.width = w
	state.height = h
	clay.SetLayoutDimensions({f32(w), f32(h)})
}

last_cursor_tile_pos: [2]i32
@(export)
on_mouse_update :: proc(pos_x: f32, pos_y: f32, button_down: bool) {
	mouse_moved = true
	clay.SetPointerState({pos_x, pos_y}, button_down)

	new_tile_pos: [2]i32 = {i32(pos_x / 32), i32(pos_y / 32)}
	if new_tile_pos != last_cursor_tile_pos {
		last_cursor_tile_pos = new_tile_pos
		client_send_message(ClientMessageCursorPosUpdate{pos = new_tile_pos})
	}
}

@(export)
on_client_connected :: proc(clientId: i32) {
	context = runtime.default_context()
	context.allocator = host_arena_alloc
	context.temp_allocator = frame_arena_alloc

	trace("Client connected id %d", clientId)

	host_on_client_connected(clientId)
}

@(export)
boot :: proc(width: i32, height: i32, flags: i32) {
	memory_init()

	context.assertion_failure_proc = on_panic
	context.allocator = persistent_arena_alloc
	context.temp_allocator = frame_arena_alloc

	if (flags == 0) {
		host_boot()
	}

	if !hot_reload_hydrate_state() {
		// Generate token
		fresnel.fill_slice_random(state.client.my_token[:])
	}

	trace("Time is %.2f", state.t)

	boot_err := client_boot(width, height)
	if boot_err != nil {
		err("Error booting: %v", boot_err)
	}

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

	mem.arena_free_all(&frame_arena)

	fresnel.metric_i32("persistent mem", i32(persistent_arena.offset))
	fresnel.metric_i32("persistent mem peak", i32(persistent_arena.peak_used))

	state.t += dt

	if state.host.is_host {
		host_tick(dt)
	}

	client_tick(dt)

	fresnel.metric_i32("temp mem", i32(frame_arena.offset))
	fresnel.metric_i32("temp mem peak", i32(frame_arena.peak_used))
	fresnel.metric_i32("temp mem count", i32(frame_arena.temp_count))
	fresnel.metric_i32("bytes sent", i32(state.bytes_sent))
	fresnel.metric_i32("bytes received", state.bytes_received)
}

@(export)
on_dev_hot_unload :: proc() {
	szr := prism.create_serializer(frame_arena_alloc)
	result := serialize_state(&szr, &state)
	if result != nil {
		err("Serialization failed! %s at %d", result, szr.offset)
	}

	fresnel.storage_set("dev_state", szr.stream[:])
}
