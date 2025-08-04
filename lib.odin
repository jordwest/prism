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

GameState :: struct #packed {
	t:                  f32,
	test:               u8,
	greeting:           string,
	width:              i32,
	height:             i32,
	is_server:          bool,
	other_pointer_down: u8,
	cursor_pos:         [2]i32,
	players:            PlayerList,
}

PlayerId :: distinct i32

PlayerMeta :: struct {
	player_id:   PlayerId,
	cursor_tile: [2]i32,
}

PlayerList :: map[PlayerId]PlayerMeta

state: GameState

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

	client_send_message(ClientMessageCursorPosUpdate{pos = {i32(pos_x), i32(pos_y)}})
}

client_send_message :: proc(msg: ClientMessage) {
	m: ClientMessage = msg
	s := prism.create_serializer(frame_arena_alloc)
	client_message_union_serialize(&s, &m)
	fresnel.client_send_message(s.stream[:])
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

server_poll :: proc() {
	msg_in := make([dynamic]u8, 100, 100)
	client_id: i32
	bytes_read := 0
	for {
		bytes_read := fresnel.server_poll_message(&client_id, msg_in[:])
		if bytes_read <= 0 {
			break
		}

		s := prism.create_deserializer(msg_in)
		msg: ClientMessage
		e := client_message_union_serialize(&s, &msg)

		if e != nil {
			err("Failed to deserialize %v", e)
		}

		switch m in msg {
		case nil:
			err("Message could not be read")
		case ClientMessageCursorPosUpdate:
			state.cursor_pos = m.pos
		case ClientMessageIdentify:
			err("identify not implemented")
		}
		// state.other_pointer_down = msg_in[2]

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

	ds := prism.create_deserializer(hot_reload_data)
	result := serialize_state(&ds, &state)
	if result != nil {
		err("Hot reload deserialization failed! %s at %d", result, ds.offset)
	}

	return true
}
