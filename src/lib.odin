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

state: ClientState
host_state: HostState

on_panic :: proc(a: string, b: string, loc: runtime.Source_Code_Location) -> ! {
	fresnel.log_panic(a, b, loc.file_path, loc.line)
	unreachable()
}

mouse_moved := true

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

hot_reload_hydrate_state :: proc() -> bool {
	hot_reload_data := make([dynamic]u8, 10000, 10000, context.temp_allocator)
	bytes_read := fresnel.storage_get("dev_state", hot_reload_data[:])
	if bytes_read <= 0 {
		warn("Dev state not loaded. Storage returned %d", bytes_read)
		return false
	}

	resize(&hot_reload_data, int(bytes_read))

	ds := prism.create_deserializer(hot_reload_data)
	result := serialize_state(&ds, &state)
	if result != nil {
		err("Hot reload deserialization failed! %s at %d", result, ds.offset)
		return false
	}

	return true
}
