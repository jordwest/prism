package main

import "fresnel"
import "prism"

host_tick :: proc(dt: f32) {
	host_poll()
}

host_boot :: proc() {
	memory_init_host()

	host_state.is_host = true
	host_state.players = make(map[PlayerId]PlayerMeta, 8, allocator = host_arena_alloc)

	fresnel.metric_i32("host mem", i32(host_arena.offset))
	fresnel.metric_i32("host mem peak", i32(host_arena.peak_used))
}

host_on_client_connected :: proc(clientId: i32) {
	host_send_message(clientId, HostMessageWelcome{})
}

@(private)
host_poll :: proc() {
	msg_in := make([dynamic]u8, 1000, 1000, frame_arena_alloc)
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

		#partial switch m in msg {
		case ClientMessageIdentify:
			host_state.newest_player_id += 1
			new_id := PlayerId(host_state.newest_player_id)
			host_state.players[new_id] = PlayerMeta {
				player_id = PlayerId(host_state.newest_player_id),
				token     = m.token,
			}
			host_send_message(client_id, HostMessageIdentifyResponse{player_id = i32(new_id)})
		}

		trace("Host got message: %v", msg)
	}
}

host_send_message :: proc(clientId: i32, msg: HostMessage) {
	m: HostMessage = msg
	s := prism.create_serializer(frame_arena_alloc)
	host_message_union_serialize(&s, &m)
	fresnel.server_send_message(clientId, s.stream[:])
}
