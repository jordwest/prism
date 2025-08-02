package main
import "base:runtime"
import clay "clay-odin"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"
import "core:sync"

TestStruct :: struct #packed {
	t:        f32,
	test:     u8,
	greeting: string,
	width:    i32,
	height:   i32,
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

foreign import wasm "my_namespace"
@(default_calling_convention = "c")
foreign wasm {
	@(link_name = "test")
	test :: proc(test_struct: ^TestStruct) -> u8 ---
	print :: proc(str: string, level: i32 = 0) ---
	clear :: proc() ---
	fill :: proc(r: f32, g: f32, b: f32, a: f32) ---
	draw_rect :: proc(x: f32, y: f32, w: f32, h: f32) ---
	draw_text :: proc(x: f32, y: f32, size: i32, text: cstring) ---
	measure_text :: proc(size: i32, text: cstring) -> i32 ---
	client_send_message :: proc(ptr: ^TestStruct, size: i32) -> i32 ---
	client_poll_message :: proc(ptr: ^TestStruct, size: i32) -> i32 ---
}

foreign import debug "debug"
@(default_calling_convention = "c")
foreign debug {
	record_line :: proc(line: i32) ---
	log_panic :: proc(prefix: string, message: string, file: string, line: i32) ---
	log_pointer :: proc(ptr: rawptr, size: i32) ---
	log_u8 :: proc(info: cstring, val: u8) ---
	metric_i32 :: proc(name: string, val: i32) ---
}

ln :: proc(loc: runtime.Source_Code_Location = #caller_location) {
	record_line(i32(loc.line))
}

printf :: proc(fmtstr: string, args: ..any) {
	result := fmt.tprintf(fmtstr, ..args)
	print(result)
}

@(export)
get_state_ptr :: proc() -> ^TestStruct {
	return &state
}

@(export)
get_state_size :: proc() -> u32 {
	return size_of(TestStruct)
}

@(export)
on_resize :: proc(w: i32, h: i32) {
	state.width = w
	state.height = h
	clay.SetLayoutDimensions({f32(w), f32(h)})
}

on_panic :: proc(a: string, b: string, loc: runtime.Source_Code_Location) -> ! {
	// printf("Panic! %s ||| %s", a, b)
	// print(strings.unsafe_string_to_cstring(b))
	// print(strings.unsafe_string_to_cstring(loc.line))
	log_panic(a, b, loc.file_path, loc.line)
	unreachable()
}

mouse_moved := true

@(export)
on_mouse_update :: proc(pos_x: f32, pos_y: f32, button_down: bool) {
	mouse_moved = true
	clay.SetPointerState({pos_x, pos_y}, button_down)
}

@(export)
tick :: proc(dt: f32) {
	// if (mouse_moved == false) {
	// 	return
	// }

	// mouse_moved = false

	context.assertion_failure_proc = on_panic
	context.allocator = persistent_arena_alloc
	context.temp_allocator = frame_arena_alloc

	metric_i32("persistent mem", i32(persistent_arena.offset))
	metric_i32("persistent mem peak", i32(persistent_arena.peak_used))

	state.t += dt
	clear()
	x := i32(50 + math.sin(state.t) * 50)
	y := 30 + i32(math.cos(state.t) * 20)
	draw_rect(f32(x), f32(y), f32(70 + math.sin(state.t * 2.0) * 20), 30)

	offset := i32(math.sin(state.t * 0.9) * 10)

	// text := fmt.tprintf("Time is %.2f", state.t)
	cstr := strings.clone_to_cstring(
		fmt.tprintf("Time is %.3f", state.t),
		allocator = context.temp_allocator,
	)
	draw_text(f32(x), f32(y + 50 + offset), 16, cstr)

	render_commands := ui_create_layout()

	for i in 0 ..< i32(render_commands.length) {
		render_command := clay.RenderCommandArray_Get(&render_commands, i)

		#partial switch render_command.commandType {
		case .Rectangle:
			// if render_command.renderData.rectangle.backgroundColor.a != 1 {
			fill(
				render_command.renderData.rectangle.backgroundColor.r,
				render_command.renderData.rectangle.backgroundColor.g,
				render_command.renderData.rectangle.backgroundColor.b,
				render_command.renderData.rectangle.backgroundColor.a,
			)
			draw_rect(
				render_command.boundingBox.x,
				render_command.boundingBox.y,
				render_command.boundingBox.width,
				render_command.boundingBox.height,
			)
		// }
		// DrawRectangle(
		// 	render_command.boundingBox,
		// 	render_command.config.rectangleElementConfig.color,
		// )
		// ... Implement handling of other command types
		case .Text:
			c := render_command.renderData.text.textColor
			fill(c.r, c.g, c.b, c.a)
			draw_text(
				render_command.boundingBox.x,
				render_command.boundingBox.y,
				i32(render_command.renderData.text.fontSize),
				strings.clone_to_cstring(
					string_from_clay_slice(render_command.renderData.text.stringContents),
					allocator = context.temp_allocator,
				),
			)
		}
	}
	metric_i32("temp mem", i32(frame_arena.offset))
	metric_i32("temp mem peak", i32(frame_arena.peak_used))
	metric_i32("temp mem count", i32(frame_arena.temp_count))
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
	width := measure_text(i32(config.fontSize), strings.clone_to_cstring(odin_string))
	return {width = f32(width), height = f32(config.fontSize)}
}

clay_error_handler :: proc "c" (errorData: clay.ErrorData) {
	print("CLAY ERROR")
}

@(export)
hello :: proc(width: i32, height: i32) {
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

	msg_in := TestStruct{}
	for (client_poll_message(&msg_in, size_of(msg_in)) > 0) {
		printf("Got message! t is %.4f", msg_in.t)
	}

	msg := TestStruct {
		t        = state.t,
		test     = 28,
		greeting = "lll",
	}

	szr := create_serializer(frame_arena_alloc)
	serialize_state(&szr, &msg)
	log_pointer(&szr.stream, i32(len(szr.stream)))

	client_send_message(&msg, size_of(msg))
	client_send_message(&msg, size_of(msg))

	ds := create_deserializer(szr.stream)
	other := TestStruct{}
	ds.stream[5] = 0
	log_pointer(&szr.stream, i32(len(szr.stream)))
	result := serialize_state(&ds, &other)
	if result != nil {
		printf("Serialization failed! %s at %d", result, ds.offset)
	}
	printf(
		"Serialization result:%s TestStruct t=%.2f test=%d greeting=%s",
		result,
		other.t,
		other.test,
		other.greeting,
	)

	trace("It works! 😃  Hey there, hot reload from 202507")
	trace("Time is %.2f", state.t)

	trace("Trace")
	info("Info")
	warn("Warn")
	err("Error")

	// Boot clay
	state.width = width
	state.height = width
	min_memory_size := clay.MinMemorySize()
	printf("Min memory size %d", min_memory_size)
	memory := make([^]u8, min_memory_size)
	clay_arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(uint(min_memory_size), memory)
	clay.Initialize(clay_arena, {f32(width), f32(height)}, {handler = clay_error_handler})

	metric_i32("clay max elements", clay.GetMaxElementCount())

	// Tell clay how to measure text
	clay.SetMeasureTextFunction(clay_measure_text, nil)

	clay.SetDebugModeEnabled(true)

	return
}
