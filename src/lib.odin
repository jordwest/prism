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

state: AppState

on_panic :: proc(a: string, b: string, loc: runtime.Source_Code_Location) -> ! {
	fresnel.log_panic(a, b, loc.file_path, loc.line)
	unreachable()
}

mouse_moved := true

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

app_context :: proc() -> runtime.Context {
	context = runtime.default_context()
	context.assertion_failure_proc = on_panic
	context.allocator = mem.panic_allocator()
	context.temp_allocator = mem.panic_allocator()
	return context
}

serialize :: proc {
	state_serialize,
	command_serialize,
	entity_id_serialize,
	player_id_serialize,
	log_entry_serialize,
	log_seq_id_serialize,
	cmd_seq_id_serialize,
	prism.serialize_array,
	prism.serialize_f32,
	prism.serialize_i32,
	prism.serialize_string,
	prism.serialize_vec2i,
	prism.serialize_u8,
}
