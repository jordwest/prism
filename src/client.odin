package main

import "core:math"
import "core:mem"
import "fresnel"
import "prism"

client_boot :: proc(width: i32, height: i32) -> Error {
	e_alloc: mem.Allocator_Error

	state.client.game.players, e_alloc = make(
		map[PlayerId]Player,
		8,
		allocator = persistent_arena_alloc,
	)
	if e_alloc != nil do return error(e_alloc)
	state.client.game.entities, e_alloc = make(
		map[EntityId]Entity,
		2048,
		allocator = persistent_arena_alloc,
	)
	if e_alloc != nil do return error(e_alloc)
	derived_init() or_return
	audio_init()
	fx_init()

	if MUSIC_ENABLED {
		audio_play(.Daudir)
	}

	state.client.zoom = DEFAULT_ZOOM
	state.client.camera = prism.spring_create(
		2,
		[2]f32{0, 0},
		k = CAMERA_SPRING_CONSTANT,
		c = CAMERA_SPRING_DAMPER,
	)

	pcg, e_alloc2 := new(PcgState, allocator = persistent_arena_alloc)
	if e_alloc2 != nil do return error(e_alloc)

	state.client.game.pcg = pcg
	procgen_init(pcg)

	return nil
}

client_tick :: proc(dt: f32) {
	error_log(client_poll())

	fresnel.clear()
	fresnel.fill(10, 10, 10, 255)
	fresnel.draw_rect(0, 0, f32(state.width), f32(state.height))

	fresnel.fill(0, 0, 0, 255)

	game := state.client.game

	if pcg, ok := game.pcg.?; ok {
		max_iterations := PCG_ITERATION_DELAY == 0 ? 100 : 1
		t0 := fresnel.now()
		for i := 0; i < max_iterations && !pcg.done; i += 1 {
			procgen_iterate(pcg)
		}
		t1 := fresnel.now()
		pcg.total_time += (t1 - t0)

		fresnel.metric_i32("djikstra_iterations", pcg.djikstra_map.iterations)
	}

	input_system(dt)
	entity_system(dt)
	render_system(dt)
	audio_system()
}

_msg_in_buf: [1000]u8

@(private)
client_poll :: proc() -> Error {
	client_id: i32
	bytes_read := 0
	for {
		bytes_read := fresnel.client_poll_message(_serialization_buffer[:])
		if bytes_read <= 0 do break // No new messages
		state.client.bytes_received += bytes_read

		s := prism.create_deserializer(_serialization_buffer[:bytes_read])
		msg: HostMessage
		e_serialization := host_message_union_serialize(&s, &msg)
		if e_serialization != nil do return error(DeserializationError{result = e_serialization, offset = s.offset, data = _serialization_buffer[:bytes_read]})

		e: Error

		if LOG_CLIENT_MESSAGES do info("[CLIENT]: %w", msg)

		switch m in msg {
		case HostMessageWelcome:
			client_send_message(
				ClientMessageIdentify {
					token = state.client.my_token,
					display_name = "Player me",
					next_log_seq = state.client.game.next_log_seq,
				},
			)
		case HostMessageIdentifyResponse:
			state.client.player_id = m.player_id
		case HostMessageCursorPos:
			if player, ok := &state.client.game.players[m.player_id]; ok {
				player.cursor_tile = m.pos
				player.cursor_updated_at = state.t
			}
		case HostMessageLogEntry:
			expected_seq := state.client.game.next_log_seq
			if m.seq > expected_seq {
				return error(
					UnexpectedSeqId{expected = state.client.game.next_log_seq, actual = m.seq},
				)
			}
			if m.seq < expected_seq {
				warn("Ignoring stale update seq=%d, expect=%d", m.seq, expected_seq)
				break
			}
			e = log_replay_entry(m.entry)
			if e != nil do error_log(e)
			state.client.game.next_log_seq += 1
			e = turn_evaluate_all()
			if e != nil do error_log(e)
		case HostMessageCommandAck:
			entity, ok := &state.client.game.entities[state.client.controlling_entity_id]
			if _local_cmd, has_local := entity._local_cmd.?; has_local {
				if m.cmd_seq >= _local_cmd.cmd_seq {
					// Server is now ahead of our local state so we can safely clear it
					entity._local_cmd = nil
				} else {
					trace("Local cmd is still newer than server")
				}
			}
		}
	}
	return nil
}

client_get_entity :: proc(entity_id: EntityId) -> ^Entity {
	return &state.client.game.entities[entity_id]
}

client_send_message :: proc(msg: ClientMessage) {
	m: ClientMessage = msg
	s := prism.create_serializer(_serialization_buffer[:])
	client_message_union_serialize(&s, &m)
	state.client.bytes_sent += i32(len(s.stream))
	fresnel.client_send_message(s.stream[:s.offset])
}
