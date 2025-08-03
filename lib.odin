package main
import "base:runtime"
import clay "clay-odin"
import "core:fmt"
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

frame_heap: [1049600]u8
// heap: [33554432]u8
heap: [5554432]u8
state: TestStruct

global_map: map[int]string

persistent_arena_alloc: mem.Allocator
persistent_arena: mem.Arena

frame_arena_alloc: mem.Allocator
frame_arena: mem.Arena

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
				render_command.renderData.rectangle.backgroundColor.a,
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

@(export)
tick :: proc(dt: f32) {
	context.assertion_failure_proc = on_panic
	context.allocator = persistent_arena_alloc
	context.temp_allocator = frame_arena_alloc

	fresnel.clear()

	render_ui()

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
	fresnel.draw_rect(f32(state.other_pointer_x), f32(state.other_pointer_y), 20, 20)

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
	hot_reload_data := make([dynamic]u8, 100000, 100000)
	bytes_read := fresnel.storage_get("dev_state", hot_reload_data[:])
	if bytes_read <= 0 {
		warn("Dev state not loaded. Storage returned %d", bytes_read)
		return false
	}

	info("Read %d bytes from hot reload state", bytes_read)

	resize(&hot_reload_data, int(bytes_read))

	fresnel.log_slice("dev state", hot_reload_data[:])
	ds := create_deserializer(hot_reload_data)
	result := serialize_state(&ds, &state)
	if result != nil {
		err("Deserialization failed! %s at %d", result, ds.offset)
	}
	info(
		"Serialization result:%s TestStruct t=%.2f test=%d greeting=%s",
		result,
		state.t,
		state.test,
		state.greeting,
	)

	return true
}

@(export)
boot :: proc(width: i32, height: i32, flags: i32) {
	context.assertion_failure_proc = on_panic
	persistent_arena = mem.Arena {
		data = heap[:],
	}
	frame_arena = mem.Arena {
		data = frame_heap[:],
	}
	persistent_arena_alloc = mem.arena_allocator(&persistent_arena)
	frame_arena_alloc = mem.arena_allocator(&frame_arena)

	context.allocator = persistent_arena_alloc
	context.temp_allocator = frame_arena_alloc

	msg := TestStruct {
		t        = state.t,
		test     = 28,
		greeting = "lll",
	}

	info("I appear to be %d", flags)

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
	printf("Min memory size %d", min_memory_size)
	memory := make([^]u8, min_memory_size)
	clay_arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(uint(min_memory_size), memory)

	clay.Initialize(clay_arena, {f32(width), f32(height)}, {handler = clay_error_handler})

	fresnel.metric_i32("clay max elements", clay.GetMaxElementCount())

	// Tell clay how to measure text
	clay.SetMeasureTextFunction(clay_measure_text, nil)

	clay.SetDebugModeEnabled(true)

	return
}
