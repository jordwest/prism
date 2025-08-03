package fresnel

foreign import wasm "core"
@(default_calling_convention = "c")
foreign wasm {
	print :: proc(str: string, level: i32 = 0) ---
	clear :: proc() ---
	fill :: proc(r: f32, g: f32, b: f32, a: f32) ---
	draw_rect :: proc(x: f32, y: f32, w: f32, h: f32) ---
	draw_text :: proc(x: f32, y: f32, size: i32, text: string) ---
	measure_text :: proc(size: i32, text: cstring) -> i32 ---
}

foreign import net "net"
@(default_calling_convention = "c")
foreign net {
	client_send_message :: proc(ptr: rawptr, size: i32) -> i32 ---
	client_poll_message :: proc(ptr: rawptr, size: i32) -> i32 ---

	server_send_message :: proc(peer_id: int, ptr: rawptr, size: i32) -> i32 ---
	server_poll_message :: proc(ptr: rawptr, size: i32) -> i32 ---
}

foreign import debug "debug"
@(default_calling_convention = "c")
foreign debug {
	record_line :: proc(line: i32) ---
	log_panic :: proc(prefix: string, message: string, file: string, line: i32) ---
	log_pointer :: proc(ptr: rawptr, size: i32) ---
	log_u8 :: proc(info: cstring, val: u8) ---
	metric_i32 :: proc(name: string, val: i32) ---
	metric_str :: proc(name: string, val: string) ---
}
