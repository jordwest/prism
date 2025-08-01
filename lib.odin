package main
import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"
import "core:sync"

TestStruct :: struct #packed {
	t: f32,
}

heap: [33554432]u8
state: TestStruct

foreign import wasm "my_namespace"
@(default_calling_convention = "c")
foreign wasm {
	@(link_name = "test")
	test :: proc(test_struct: ^TestStruct) -> u8 ---
	print :: proc(str: cstring) ---
	clear :: proc() ---
	draw_rect :: proc(x: f32, y: f32, w: f32, h: f32) ---
	draw_text :: proc(x: f32, y: f32, text: cstring) ---
}

foreign import debug "debug"
@(default_calling_convention = "c")
foreign debug {
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

@(export)
tick :: proc(dt: f32) {
	arena := mem.Arena {
		data = heap[:],
	}
	context.allocator = mem.arena_allocator(&arena)
	context.temp_allocator = mem.arena_allocator(&arena)

	state.t += dt
	clear()
	x := i32(50 + math.sin(state.t) * 50)
	y := 30 + i32(math.cos(state.t) * 20)
	draw_rect(f32(x), f32(y), f32(70 + math.sin(state.t * 2.0) * 20), 30)

	offset := i32(math.sin(state.t * 0.9) * 10)

	// text := fmt.tprintf("Time is %.2f", state.t)
	cstr := strings.clone_to_cstring(fmt.tprintf("Time is %.3f", state.t))
	draw_text(f32(x), f32(y + 50 + offset), cstr)

	mem.arena_free_all(&arena)
}

@(export)
hello :: proc(s: ^TestStruct) {
	arena := mem.Arena {
		data = heap[:],
	}
	arena_alloc := mem.arena_allocator(&arena)

	tracking: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking, arena_alloc, arena_alloc)
	context.allocator = mem.tracking_allocator(&tracking)

	print("It works! 😃  Hey there, hot reload from 202507jj")
	printf("Time is %.2f", state.t)

	defer {
		if len(tracking.allocation_map) > 0 {
			printf("=== %v allocations not freed: ===\n", len(tracking.allocation_map))
			for _, entry in tracking.allocation_map {
				printf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		if len(tracking.bad_free_array) > 0 {
			printf("=== %v incorrect frees: ===\n", len(tracking.bad_free_array))
			for entry in tracking.bad_free_array {
				printf("- %p @ %v\n", entry.memory, entry.location)
			}
		}
		mem.tracking_allocator_destroy(&tracking)
	}

	return
}
