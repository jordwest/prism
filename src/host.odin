package main

import "fresnel"
import "prism"
import "core:mem"

host_tick :: proc(dt: f32) {
	host_poll()
}

host_boot :: proc() {
	memory_init_host()

	alloc_error: mem.Allocator_Error

	state.host.is_host = true
	state.host.players, alloc_error = make(map[PlayerId]Player, 8, allocator = host_arena_alloc)
	if alloc_error != nil {
		err("Could not allocate entity map %v", alloc_error)
	}

	state.host.entities, alloc_error = make(map[EntityId]Entity, MAX_ENTITIES)
	if alloc_error != nil {
		err("Could not allocate entity map %v", alloc_error)
	}
	p := host_spawn_entity(&ENTITY_PLAYER)
	p.pos = {2, 5}

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
			state.host.newest_player_id += 1
			new_id := PlayerId(state.host.newest_player_id)
			state.host.players[new_id] = Player {
				player_id = PlayerId(state.host.newest_player_id),
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

host_spawn_entity :: proc(meta: ^EntityMeta) -> ^Entity {
	state.host.newest_entity_id += 1
	id := EntityId(state.host.newest_entity_id)

	state.host.entities[id] = Entity {
		id   = id,
		meta = meta,
	}

	return &state.host.entities[id]
}
