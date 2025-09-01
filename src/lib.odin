package main
import "base:runtime"
import clay "clay-odin"
import "core:crypto/legacy/sha1"
import "core:fmt"
import "core:hash"
import "core:math"
import "core:mem"
import "core:strings"
import "core:sync"
import "fresnel"
import "prism"

on_panic :: proc(a: string, b: string, loc: runtime.Source_Code_Location) -> ! {
	fresnel.log_panic(a, b, loc.file_path, loc.line)
	unreachable()
}

// Example measure text function
clay_measure_text :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	userData: rawptr,
) -> clay.Dimensions {
	context = app_context()
	// clay.TextElementConfig contains members such as fontId, fontSize, letterSpacing, etc..
	// Note: clay.String->chars is not guaranteed to be null terminated
	odin_string := string_from_clay_slice(text)
	width := fresnel.measure_text(i32(config.fontSize), odin_string)
	return {width = f32(width), height = f32(config.fontSize)}
}

clay_error_handler :: proc "c" (errorData: clay.ErrorData) {
	context = app_context()
	err("CLAY ERROR %s", errorData.errorType)
}

hot_reload_hydrate_state :: proc() -> bool {
	bytes_read := fresnel.storage_get("dev_state", _serialization_buffer[:])
	if bytes_read <= 0 {
		warn("Dev state not loaded. Storage returned %d", bytes_read)
		return false
	}

	buf := _serialization_buffer[:bytes_read]

	ds := prism.create_deserializer(buf[:])
	result := serialize(&ds, &state)
	if result != nil {
		err("hot reload deserialization failed! %s at %d", result, ds.offset)
		return false
	}

	return true
}

@(export)
on_resize :: proc "c" (w: i32, h: i32) {
	context = app_context()

	state.width = w
	state.height = h
	clay.SetCurrentContext(ctx1)
	clay.SetLayoutDimensions({f32(w), f32(h)})
	clay.SetCurrentContext(ctx2)
	clay.SetLayoutDimensions({f32(w / 2) - 80, f32(h / 2)})
}

last_cursor_tile_pos: TileCoord
@(export)
on_mouse_move :: proc "c" (pos_x: f32, pos_y: f32, button_down: bool) {
	context = app_context()

	clay.SetCurrentContext(ctx1)
	clay.SetPointerState({pos_x, pos_y}, button_down)
	screen_pos: ScreenCoord = {pos_x, pos_y}
	state.client.cursor_pos = tile_coord(screen_pos)
	state.client.cursor_screen_pos = screen_pos
	state.client.cursor_last_moved = state.t


	if state.client.cursor_pos != last_cursor_tile_pos {
		last_cursor_tile_pos = state.client.cursor_pos
		state.client.cursor_hidden = false
	}
}

@(export)
on_mouse_button :: proc "c" (pos_x: f32, pos_y: f32, button_down: bool, button: i32) {
	context = app_context()
	state.client.cursor_last_moved = state.t
	ui_tooltip_latch = false

	clay.SetCurrentContext(ctx1)
	clay.SetPointerState({pos_x, pos_y}, button_down)
}

@(export)
on_client_connected :: proc "c" (clientId: i32) {
	context = app_context()

	trace("Client connected id %d", clientId)

	host_on_client_connected(ClientId(clientId))
}

@(export)
boot :: proc "c" (width: i32, height: i32, flags: i32) {
	context = runtime.default_context()
	memory_init()
	context = app_context()

	info("Boot width=%d height=%d flags=%d", width, height, flags)
	info("Size of AppState: %d", size_of(AppState))
	info("Size of HostState: %d", size_of(HostState))
	info("Size of ClientState: %d", size_of(ClientState))
	info("Size of GameState: %d", size_of(GameState))

	debug_init()

	host_boot_err := host_boot()
	if host_boot_err != nil {
		err("Error booting host: %v", host_boot_err)
		state.host.crashed = true
	}

	state.client.join_mode = DEBUG_SPECTATE ? .Spectate : .Play

	trace("Is host: %w", state.host.is_host)

	if !hot_reload_hydrate_state() {
		// Generate token
		fresnel.fill_slice_random(state.client.my_token[:])
	}

	trace("Time is %.2f", state.t)

	boot_err := client_boot(width, height)
	if boot_err != nil {
		err("Error booting client: %v", boot_err)
		state.client.crashed = true
	}
	info(
		"Size of Entity: %d (x%d = %d)",
		size_of(Entity),
		cap(state.client.game.entities),
		size_of(Entity) * cap(state.client.game.entities),
	)

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

	ctx1 = clay.Initialize(clay_arena, {f32(width), f32(height)}, {handler = clay_error_handler})

	// Tell clay how to measure text
	clay.SetMeasureTextFunction(clay_measure_text, nil)

	clay.SetDebugModeEnabled(CLAY_DEBUG_ENABLED)

	clay.SetMaxElementCount(4096)
	min_memory_size = clay.MinMemorySize()
	clay_arena_tooltip: clay.Arena = clay.CreateArenaWithCapacityAndMemory(
		uint(min_memory_size),
		raw_data(clay_memory_tooltip[:]),
	)
	ctx2 = clay.Initialize(
		clay_arena_tooltip,
		{f32(width / 3), f32(height)},
		{handler = clay_error_handler},
	)
	// clay.SetCurrentContext(ctx1)

	fresnel.metric_i32("clay max elements", clay.GetMaxElementCount())

	// Tell clay how to measure text
	clay.SetMeasureTextFunction(clay_measure_text, nil)

	return
}

ctx1: ^clay.Context
ctx2: ^clay.Context

@(export)
tick :: proc "c" (dt: f32) {
	context = app_context()

	state.client.frame_iter_count = 0

	state.t += dt

	if state.host.is_host && !state.host.crashed {
		host_tick(dt)
	}

	if !state.client.crashed {
		e := client_frame(dt)
		if e != nil do error_log(e)
	}

	debug_tick(dt)

	if state.host.is_host {
		fresnel.metric_i32("host tx ↑", state.host.bytes_sent)
		fresnel.metric_i32("host rx ↓", state.host.bytes_received)
	}
	fresnel.metric_i32("tx ↑", state.client.bytes_sent)
	fresnel.metric_i32("rx ↓", state.client.bytes_received)
	memory_log_metrics()
}

@(export)
on_dev_hot_unload :: proc "c" () {
	context = app_context()

	szr := prism.create_serializer(_serialization_buffer[:])
	result := serialize(&szr, &state)
	if result != nil {
		err("Serialization failed! %s at %d", result, szr.offset)
	}

	fresnel.storage_set("dev_state", szr.stream[:szr.offset])
}

when TESTS_ENABLED {
	@(export)
	tests :: proc "c" () {
		context = runtime.default_context()
		memory_init()

		context.assertion_failure_proc = on_panic
		context.allocator = mem.panic_allocator()
		context.temp_allocator = mem.panic_allocator()

		tests_run_all()
	}
}

app_context :: proc() -> runtime.Context {
	context = runtime.default_context()
	context.assertion_failure_proc = on_panic
	context.allocator = mem.panic_allocator()
	context.temp_allocator = mem.panic_allocator()
	return context
}

Percent :: prism.Percent

serialize :: proc {
	state_serialize,
	command_serialize,
	entity_id_serialize,
	item_id_serialize,
	player_id_serialize,
	log_entry_serialize,
	log_seq_id_serialize,
	cmd_seq_id_serialize,
	prism.serialize_array,
	prism.serialize_f32,
	prism.serialize_i32,
	prism.serialize_u64,
	prism.serialize_string,
	prism.serialize_vec2i,
	prism.serialize_u8,
	prism.serialize_bufstring,
}

rng_new :: proc(stream: u64) -> prism.SplitMixState {
	return prism.rand_splitmix_create(state.client.game.seed, stream)
}
rng_dice :: prism.rand_splitmix_get_dice_roll
rng_range :: prism.rand_splitmix_get_i32_range
rng_bool :: prism.rand_splitmix_get_bool
rng_seed_random :: proc(rng: ^prism.SplitMixState) {
	bytes: [4]u8
	fresnel.fill_slice_random(bytes[:])
	rng_add(rng, transmute(i32)bytes)
}
rng_add :: proc {
	prism.rand_splitmix_add_f32,
	prism.rand_splitmix_add_i32,
	prism.rand_splitmix_add_int,
	prism.rand_splitmix_add_u64,
}

into_iter :: proc {
	container_iterator,
	prism.aabb_iterator,
}

iterate :: proc {
	container_iterate,
	prism.aabb_iterate,
}
