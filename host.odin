package main

import "fresnel"
import "prism"

host_tick :: proc(dt: f32) {
  	server_poll()
}

host_boot :: proc() {
    memory_init_host()

    host_state.is_host = true
    host_state.players = make(map[PlayerId]PlayerMeta, 8, allocator = host_arena_alloc)

    fresnel.metric_i32("host mem", i32(host_arena.offset))
	fresnel.metric_i32("host mem peak", i32(host_arena.peak_used))
}

@(private)
server_poll :: proc() {
	msg_in := make([dynamic]u8, 100, 100, frame_arena_alloc)
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
