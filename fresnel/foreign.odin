package fresnel

foreign import core "core"
@(default_calling_convention = "c")
foreign core {
	print :: proc(str: string, level: i32 = 0) ---
	clear :: proc() ---
	fill :: proc(r: f32, g: f32, b: f32, a: f32) ---
	draw_rect :: proc(x: f32, y: f32, w: f32, h: f32) ---
	draw_text :: proc(x: f32, y: f32, size: i32, text: string) ---
	draw_image :: proc(image_id: i32, sx: f32, sy: f32, sw: f32, sh: f32, dx: f32, dy: f32, dw: f32, dh: f32) ---
	measure_text :: proc(size: i32, text: string) -> i32 ---
	storage_set :: proc(key: string, slice: []u8) ---
	storage_get :: proc(key: string, slice: []u8) -> i32 ---
}

foreign import net "net"
@(default_calling_convention = "c")
foreign net {
	// Send message client -> server
	client_send_message :: proc(slice: []u8) -> i32 ---
	// Receive messages from server
	client_poll_message :: proc(slice: []u8) -> i32 ---

	// TODO: Should these be host_* instead of server_? Since it may be relayed
	// Send message server -> client
	server_send_message :: proc(client_id: i32, slice: []u8) -> i32 ---
	// Receive messages from clients.
	// Writes output to both client_id and slice
	server_poll_message :: proc(client_id: ^i32, slice: []u8) -> i32 ---
}

foreign import debug "debug"
@(default_calling_convention = "c")
foreign debug {
	time :: proc() -> i32 ---
	log_panic :: proc(prefix: string, message: string, file: string, line: i32) ---
	log_slice :: proc(name: string, ptr: []u8) ---
	metric_i32 :: proc(name: string, val: i32) ---
	metric_str :: proc(name: string, val: string) ---
}
