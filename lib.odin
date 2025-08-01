package main
import "base:runtime"
import clay "clay-odin"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"
import "core:sync"

TestStruct :: struct #packed {
	t: f32,
}

frame_heap: [1049600]u8
heap: [33554432]u8
state: TestStruct

persistent_arena_alloc: mem.Allocator
persistent_arena: mem.Arena

frame_arena_alloc: mem.Allocator
frame_arena: mem.Arena

foreign import wasm "my_namespace"
@(default_calling_convention = "c")
foreign wasm {
	@(link_name = "test")
	test :: proc(test_struct: ^TestStruct) -> u8 ---
	print :: proc(str: cstring) ---
	clear :: proc() ---
	fill :: proc(r: f32, g: f32, b: f32, a: f32) ---
	draw_rect :: proc(x: f32, y: f32, w: f32, h: f32) ---
	draw_text :: proc(x: f32, y: f32, text: cstring) ---
	measure_text :: proc(text: cstring) -> i32 ---
}

foreign import debug "debug"
@(default_calling_convention = "c")
foreign debug {
	log_panic :: proc(prefix: string, message: string, file: string, line: i32) ---
	log_pointer :: proc(ptr: rawptr, size: i32) ---
	log_u8 :: proc(info: cstring, val: u8) ---
}

printf :: proc(fmtstr: string, args: ..any) {
	result := fmt.tprintf(fmtstr, ..args)
	cstr := strings.unsafe_string_to_cstring(result)
	print(cstr)
}

@(export)
get_state_ptr :: proc() -> ^TestStruct {
	return &state
}

@(export)
get_state_size :: proc() -> u32 {
	return size_of(TestStruct)
}

on_panic :: proc(a: string, b: string, loc: runtime.Source_Code_Location) -> ! {
	// printf("Panic! %s ||| %s", a, b)
	// print(strings.unsafe_string_to_cstring(b))
	// print(strings.unsafe_string_to_cstring(loc.line))
	log_panic(a, b, loc.file_path, loc.line)
	unreachable()
}

@(export)
tick :: proc(dt: f32) {
	context.assertion_failure_proc = on_panic
	context.allocator = persistent_arena_alloc
	context.temp_allocator = frame_arena_alloc

	state.t += dt
	clear()
	x := i32(50 + math.sin(state.t) * 50)
	y := 30 + i32(math.cos(state.t) * 20)
	draw_rect(f32(x), f32(y), f32(70 + math.sin(state.t * 2.0) * 20), 30)

	offset := i32(math.sin(state.t * 0.9) * 10)

	// text := fmt.tprintf("Time is %.2f", state.t)
	cstr := strings.clone_to_cstring(fmt.tprintf("Time is %.3f", state.t))
	draw_text(f32(x), f32(y + 50 + offset), cstr)

	render_commands := ui_create_layout()

	for i in 0 ..< i32(render_commands.length) {
		render_command := clay.RenderCommandArray_Get(&render_commands, i)

		#partial switch render_command.commandType {
		case .Rectangle:
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
		// DrawRectangle(
		// 	render_command.boundingBox,
		// 	render_command.config.rectangleElementConfig.color,
		// )
		// ... Implement handling of other command types
		case .Text:
			fill(0, 0, 0, 255)
			draw_text(
				render_command.boundingBox.x,
				render_command.boundingBox.y,
				strings.clone_to_cstring(
					string_from_clay_slice(render_command.renderData.text.stringContents),
				),
			)
		}
	}

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
	width := measure_text(strings.clone_to_cstring(odin_string))
	return {width = f32(width), height = f32(config.fontSize)}
}

clay_error_handler :: proc "c" (errorData: clay.ErrorData) {
	print("CLAY ERROR")
}


@(export)
hello :: proc(s: ^TestStruct) {
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

	print("It works! 😃  Hey there, hot reload from 202507jj")
	printf("Time is %.2f", state.t)

	// Boot clay

	min_memory_size := clay.MinMemorySize()
	memory := make([^]u8, min_memory_size)
	clay_arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(uint(min_memory_size), memory)
	clay.Initialize(clay_arena, {1080, 720}, {handler = clay_error_handler})

	// Tell clay how to measure text
	clay.SetMeasureTextFunction(clay_measure_text, nil)

	return
}
