package main

import "base:runtime"
import clay "clay-odin"
import "core:mem"
import "fresnel"
import "prism"

@(export)
on_resize :: proc "c" (w: i32, h: i32) {
	context = runtime.default_context()
	context.temp_allocator = frame_arena_alloc
	state.width = w
	state.height = h
	clay.SetLayoutDimensions({f32(w), f32(h)})
}

last_cursor_tile_pos: TileCoord
@(export)
on_mouse_update :: proc "c" (pos_x: f32, pos_y: f32, button_down: bool) {
	context = runtime.default_context()
	mouse_moved = true
	clay.SetPointerState({pos_x, pos_y}, button_down)
	screen_pos: ScreenCoord = {pos_x, pos_y}
	state.client.cursor_pos = tile_coord(screen_pos)

	if state.client.cursor_pos != last_cursor_tile_pos {
		last_cursor_tile_pos = state.client.cursor_pos

		if CURSOR_REPORTING_ENABLED {
			client_send_message(ClientMessageCursorPosUpdate{pos = state.client.cursor_pos})
		}
	}
}

@(export)
on_client_connected :: proc "c" (clientId: i32) {
	context = runtime.default_context()
	context.allocator = host_arena_alloc
	context.temp_allocator = frame_arena_alloc

	trace("Client connected id %d", clientId)

	host_on_client_connected(clientId)
}

@(export)
boot :: proc "c" (width: i32, height: i32, flags: i32) {
	context = runtime.default_context()
	memory_init()

	context.assertion_failure_proc = on_panic
	context.allocator = persistent_arena_alloc
	context.temp_allocator = frame_arena_alloc

	trace("Boot width=%d height=%d flags=%d", width, height, flags)
	trace("Size of AppState: %d", size_of(AppState))
	trace("Size of HostState: %d", size_of(HostState))
	trace("Size of ClientState: %d", size_of(ClientState))
	trace("Size of SharedState: %d", size_of(SharedState))

	if (flags == 0) {
		host_boot_err := host_boot()
		if host_boot_err != nil {
			err("Error starting host: %v", host_boot_err)
		}
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
	state.height = height
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
tick :: proc "c" (dt: f32) {
	context = runtime.default_context()
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
on_dev_hot_unload :: proc "c" () {
	context = runtime.default_context()
	szr := prism.create_serializer(frame_arena_alloc)
	result := serialize_state(&szr, &state)
	if result != nil {
		err("Serialization failed! %s at %d", result, szr.offset)
	}

	fresnel.storage_set("dev_state", szr.stream[:])
}
