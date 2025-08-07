package main

import "core:math"
import "core:mem"
import "fresnel"
import "prism"

ClientError :: union {
	mem.Allocator_Error,
}

client_boot :: proc(width: i32, height: i32) -> ClientError {
	state.client.common.players = make(map[PlayerId]Player, 8) or_return
	state.client.common.entities = make(map[EntityId]Entity, 2048) or_return
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
	error_log(client_poll())

	fresnel.clear()
	fresnel.fill(10, 10, 10, 255)
	fresnel.draw_rect(0, 0, f32(state.width), f32(state.height))

	fresnel.fill(0, 0, 0, 255)

	input_system(dt)
	render_system(dt)
}

@(private)
client_poll :: proc() -> Error {
	msg_in := make([dynamic]u8, 1000, 1000, frame_arena_alloc)
	client_id: i32
	bytes_read := 0
	for {
		bytes_read := fresnel.client_poll_message(msg_in[:])
		if bytes_read <= 0 do break // No new messages
		state.bytes_received += bytes_read

		msg_in[0] = 34
		s := prism.create_deserializer(msg_in)
		msg: HostMessage
		e := host_message_union_serialize(&s, &msg)
		if e != nil do return error(DeserializationError{result = e, data = msg_in[:bytes_read]})

		switch m in msg {
		case HostMessageWelcome:
			client_send_message(
				ClientMessageIdentify{token = state.client.my_token, display_name = "Player me"},
			)
		case HostMessageIdentifyResponse:
			state.client.player_id = m.player_id
			state.client.controlling_entity_id = m.entity_id
		case HostMessageCursorPos:
			player, ok := &state.client.common.players[m.player_id]
			if ok {
				player.cursor_tile = m.pos
				player.cursor_updated_at = state.t
			}
		case HostMessageEvent:
			client_replay_event(m.event)
		}

		if CLIENT_LOG_MESSAGES do info("[CLIENT]: %w", msg)
	}
	return nil
}

client_replay_event :: proc(event: Event) {
	error := event_handle(&state.client.common, event, false)
	if error != nil {
		err("Replaying event on client\n\n%w\n\n%w", error, event)
	}
}

client_get_entity :: proc(entity_id: EntityId) -> ^Entity {
	return &state.client.common.entities[entity_id]
}

client_send_message :: proc(msg: ClientMessage) {
	m: ClientMessage = msg
	s := prism.create_serializer(frame_arena_alloc)
	client_message_union_serialize(&s, &m)
	state.bytes_sent += len(s.stream)
	fresnel.client_send_message(s.stream[:])
}
