package main

import "core:math"
import "core:mem"
import "fresnel"
import "prism"

ClientError :: union {
	mem.Allocator_Error,
}

client_boot :: proc(width: i32, height: i32) -> ClientError {
	state.client.players = make(map[PlayerId]Player, 8) or_return
	state.client.entities = make(map[EntityId]Entity, 2048) or_return
	state.client.zoom = DEFAULT_ZOOM
	state.client.camera = prism.spring_create(
		2,
		[2]f32{0, 0},
		k = CAMERA_SPRING_CONSTANT,
		c = CAMERA_SPRING_DAMPER,
	)
	return nil
}

client_tick :: proc(dt: f32) {
	client_poll()

	fresnel.clear()
	fresnel.fill(10, 10, 10, 255)
	fresnel.draw_rect(0, 0, f32(state.width), f32(state.height))

	fresnel.fill(0, 0, 0, 255)

	input_system(dt)
	render_system(dt)
}

@(private)
client_poll :: proc() {
	msg_in := make([dynamic]u8, 1000, 1000, frame_arena_alloc)
	client_id: i32
	bytes_read := 0
	for {
		bytes_read := fresnel.client_poll_message(msg_in[:])
		if bytes_read <= 0 {
			break
		}
		state.bytes_received += bytes_read

		s := prism.create_deserializer(msg_in)
		msg: HostMessage
		e := host_message_union_serialize(&s, &msg)

		if e != nil {
			err("Failed to deserialize %v", e)
		}

		switch m in msg {
		case HostMessageWelcome:
			client_send_message(
				ClientMessageIdentify{token = state.client.my_token, display_name = "Player me"},
			)
		case HostMessageIdentifyResponse:
			state.client.player_id = m.player_id
			state.client.controlling_entity_id = m.entity_id

		case HostMessageCursorPos:
			player, ok := &state.client.players[m.player_id]
			if ok {
				player.cursor_tile = m.pos
				player.cursor_updated_at = state.t
			}
		case HostMessageEvent:
			switch ev in m.event {
			case EventEntitySpawned:
				state.client.entities[ev.entity.id] = ev.entity
			case EventEntityMoved:
				client_get_entity(ev.entity_id).pos = ev.pos
			case EventPlayerJoined:
				state.client.players[ev.player_id] = Player {
					player_id        = ev.player_id,
					player_entity_id = ev.player_entity_id,
					cursor_tile      = {0, 0},
					_cursor_spring   = prism.spring_create(2, [2]f32{0, 0}, k = 40, c = 10),
				}
				if e, ok := &state.client.entities[ev.player_entity_id]; ok {
					e.player_id = ev.player_id
				} else {
					warn("Player entity does not exist")
				}
			case EventEntityCommandChanged:
				e, ok := &state.client.entities[ev.entity_id]
				if ok {
					e.cmd = ev.cmd
					if p, is_player := &state.client.players[e.player_id.? or_else 0]; is_player {
						// Mark their cursor as stale to hide it immediately
						p.cursor_updated_at = 0
					}

					if _local_cmd, has_local := e._local_cmd.?; has_local {
						if ev.seq >= _local_cmd.seq {
							trace("Clearing local cmd %d, %d", ev.seq, _local_cmd.seq)
							// Server is now ahead of our local state so we can safely clear it
							e._local_cmd = nil
						} else {
							trace("Local cmd is still newer than server")
						}
					}
				}
			}
		}

		if CLIENT_LOG_MESSAGES do info("[CLIENT]: %w", msg)
	}
}

client_get_entity :: proc(entity_id: EntityId) -> ^Entity {
	return &state.client.entities[entity_id]
}

client_send_message :: proc(msg: ClientMessage) {
	m: ClientMessage = msg
	s := prism.create_serializer(frame_arena_alloc)
	client_message_union_serialize(&s, &m)
	state.bytes_sent += len(s.stream)
	fresnel.client_send_message(s.stream[:])
}
