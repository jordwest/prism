package main
import "base:runtime"
import clay "clay-odin"
import "config"
import "core:crypto/legacy/sha1"
import "core:fmt"
import "core:hash"
import "core:math"
import "core:mem"
import "core:strings"
import "core:sync"
import "fresnel"

TestStruct :: struct #packed {
	t:                  f32,
	test:               u8,
	greeting:           string,
	width:              i32,
	height:             i32,
	is_server:          bool,
	other_pointer_x:    u8,
	other_pointer_y:    u8,
	other_pointer_down: u8,
}

state: TestStruct

printf :: proc(fmtstr: string, args: ..any) {
	result := fmt.tprintf(fmtstr, ..args)
	fresnel.print(result)
}

@(export)
on_resize :: proc(w: i32, h: i32) {
	state.width = w
	state.height = h
	clay.SetLayoutDimensions({f32(w), f32(h)})
}

on_panic :: proc(a: string, b: string, loc: runtime.Source_Code_Location) -> ! {
	fresnel.log_panic(a, b, loc.file_path, loc.line)
	unreachable()
}

mouse_moved := true

@(export)
on_mouse_update :: proc(pos_x: f32, pos_y: f32, button_down: bool) {
	mouse_moved = true
	clay.SetPointerState({pos_x, pos_y}, button_down)

	msg_data := []u8{u8(pos_x), u8(pos_y), u8(button_down)}
	fresnel.client_send_message(msg_data)
}

render_ui :: proc() {
	render_commands := ui_layout_create()

	for i in 0 ..< i32(render_commands.length) {
		render_command := clay.RenderCommandArray_Get(&render_commands, i)

		#partial switch render_command.commandType {
		case .Rectangle:
			// if render_command.renderData.rectangle.backgroundColor.a != 1 {
			fresnel.fill(
				render_command.renderData.rectangle.backgroundColor.r,
				render_command.renderData.rectangle.backgroundColor.g,
				render_command.renderData.rectangle.backgroundColor.b,
				render_command.renderData.rectangle.backgroundColor.a / 255,
			)
			fresnel.draw_rect(
				render_command.boundingBox.x,
				render_command.boundingBox.y,
				render_command.boundingBox.width,
				render_command.boundingBox.height,
			)
		case .Text:
			c := render_command.renderData.text.textColor
			fresnel.fill(c.r, c.g, c.b, c.a)
			fresnel.draw_text(
				render_command.boundingBox.x,
				render_command.boundingBox.y,
				i32(render_command.renderData.text.fontSize),
				string_from_clay_slice(render_command.renderData.text.stringContents),
			)
		}
	}
}

SplitMixState :: struct {
	state: u64,
}
splitmix_state := SplitMixState{}

next_int :: proc() -> u64 {
	splitmix_state.state += 0x9e3779b97f4a7c15
	z: u64 = splitmix_state.state
	z = (z ~ (z >> 30)) * 0xbf58476d1ce4e5b9
	z = (z ~ (z >> 27)) * 0x94d049bb133111eb
	return z ~ (z >> 31)
}

rand_int_at :: proc(x: u64, y: u64) -> u64 {
	state := x + y * 0x9e3779b97f4a7c15
	z: u64 = state
	z = (z ~ (z >> 30)) * 0xbf58476d1ce4e5b9
	z = (z ~ (z >> 27)) * 0x94d049bb133111eb
	return z ~ (z >> 31)
}
rand_float_at :: proc(x: u64, y: u64) -> f64 {
	return f64(rand_int_at(x, y)) / f64(1 << 64)
}

next_float :: proc() -> f64 {
	return f64(next_int()) / f64(1 << 64)
}

rand_f32 :: proc(data: []u8) -> f32 {
	v := f32(next_float())

	return v
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
	t0 := fresnel.time()
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
	t1 := fresnel.time()
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

// Example measure text function
clay_measure_text :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	userData: rawptr,
) -> clay.Dimensions {
	context = runtime.default_context()
	context.allocator = frame_arena_alloc
	context.temp_allocator = frame_arena_alloc
	// clay.TextElementConfig contains members such as fontId, fontSize, letterSpacing, etc..
	// Note: clay.String->chars is not guaranteed to be null terminated
	odin_string := string_from_clay_slice(text)
	width := fresnel.measure_text(i32(config.fontSize), odin_string)
	return {width = f32(width), height = f32(config.fontSize)}
}

clay_error_handler :: proc "c" (errorData: clay.ErrorData) {
	context = runtime.default_context()
	context.allocator = persistent_arena_alloc
	context.temp_allocator = frame_arena_alloc
	err("CLAY ERROR %s", errorData.errorType)
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

server_poll :: proc() {
	msg_in: [100]u8
	client_id: i32
	bytes_read := 0
	for {
		bytes_read := fresnel.server_poll_message(&client_id, msg_in[:])
		if bytes_read <= 0 {
			break
		}

		state.other_pointer_x = msg_in[0]
		state.other_pointer_y = msg_in[1]
		state.other_pointer_down = msg_in[2]

		// trace("Server message received from %d", client_id)
		// fresnel.log_slice("message in", msg_in[:bytes_read])

		// fresnel.server_send_message()
	}
}

hot_reload_hydrate_state :: proc() -> bool {
	hot_reload_data := make([dynamic]u8, 100000, 100000, context.temp_allocator)
	bytes_read := fresnel.storage_get("dev_state", hot_reload_data[:])
	if bytes_read <= 0 {
		warn("Dev state not loaded. Storage returned %d", bytes_read)
		return false
	}

	info("Read %d bytes from hot reload state", bytes_read)

	resize(&hot_reload_data, int(bytes_read))

	ds := create_deserializer(hot_reload_data)
	result := serialize_state(&ds, &state)
	if result != nil {
		err("Hot reload deserialization failed! %s at %d", result, ds.offset)
	}

	return true
}

@(export)
boot :: proc(width: i32, height: i32, flags: i32) {
	memory_init()

	context.assertion_failure_proc = on_panic
	context.allocator = persistent_arena_alloc
	context.temp_allocator = frame_arena_alloc

	msg := TestStruct {
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

	clay.SetDebugModeEnabled(config.CLAY_DEBUG_ENABLED)

	return
}
