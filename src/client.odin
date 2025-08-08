package main

import "core:math"
import "core:mem"
import "fresnel"
import "prism"

client_boot :: proc(width: i32, height: i32) -> Error {
	e_alloc: mem.Allocator_Error

	state.client.game.players, e_alloc = make(map[PlayerId]Player, 8)
	if e_alloc != nil do return error(e_alloc)
	state.client.game.entities, e_alloc = make(map[EntityId]Entity, 2048)
	if e_alloc != nil do return error(e_alloc)
	state.client.game.entity_djikstra_maps, e_alloc = make(
		map[EntityId]prism.DjikstraMap(LEVEL_WIDTH, LEVEL_HEIGHT),
		MAX_PLAYERS,
	)
	if e_alloc != nil do return error(e_alloc)

	state.client.zoom = DEFAULT_ZOOM
	state.client.camera = prism.spring_create(
		2,
		[2]f32{0, 0},
		k = CAMERA_SPRING_CONSTANT,
		c = CAMERA_SPRING_DAMPER,
	)
	e_alloc = prism.djikstra_init(&state.client.djikstra)
	if e_alloc != nil do return error(e_alloc)

	pcg := new(PcgState)
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

		/*
		// TODO: This is just a test for visualisation purposes for now
		prism.djikstra_clear(&pcg.djikstra_map)
		prism.djikstra_add_origin(&pcg.djikstra_map, Vec2i(game.spawn_point))
		prism.djikstra_iterate(&pcg.djikstra_map)

		current_cost := pcg.djikstra_map.max_cost
		path := make([dynamic]([2]i32), 0, int(current_cost), allocator = context.temp_allocator)

		// Path to origin
		for pos := pcg.djikstra_map.max_cost_coord; pos != Vec2i(game.spawn_point); {
			append(&path, pos)
			cheapest_next_pos := pos
			for offset in prism.NEIGHBOUR_TILES_8D {
				check_coord := pos + offset
				tile, ok := prism.djikstra_tile(&pcg.djikstra_map, check_coord).?
				if ok {
					if cost, has_cost := tile.cost.?; has_cost {
						if cost < current_cost {
							current_cost = cost
							cheapest_next_pos = check_coord
						}
					}
				}
			}
			pos = cheapest_next_pos
		}

		// Rerun djikstra with path to exit
		prism.djikstra_clear(&pcg.djikstra_map)
		for path_pos in path {
			prism.djikstra_add_origin(&pcg.djikstra_map, path_pos)
		}
		// prism.djikstra_add_origin(&pcg.djikstra_map, Vec2i(state.client.cursor_pos))
		prism.djikstra_iterate(&pcg.djikstra_map)
		*/

		fresnel.metric_i32("djikstra_iterations", pcg.djikstra_map.iterations)
	}

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
		state.client.bytes_received += bytes_read

		s := prism.create_deserializer(msg_in)
		msg: HostMessage
		e := host_message_union_serialize(&s, &msg)
		if e != nil do return error(DeserializationError{result = e, offset = s.offset, data = msg_in[:bytes_read]})

		if CLIENT_LOG_MESSAGES do info("[CLIENT]: %w", msg)

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
			log_replay_entry(m.entry)
			state_clear_djikstra_maps()
			state.client.game.next_log_seq += 1
		case HostMessageCommandAck:
			entity, ok := &state.client.game.entities[state.client.controlling_entity_id]
			if _local_cmd, has_local := entity._local_cmd.?; has_local {
				if m.cmd_seq >= _local_cmd.cmd_seq {
					trace("Clearing local cmd %d, %d", m.cmd_seq, _local_cmd.cmd_seq)
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

client_replay_event :: proc(event: Event) {
	error := event_handle(&state.client.game, event, false)
	if error != nil {
		err("Replaying event on client\n\n%w\n\n%w", error, event)
	}
}

client_get_entity :: proc(entity_id: EntityId) -> ^Entity {
	return &state.client.game.entities[entity_id]
}

client_send_message :: proc(msg: ClientMessage) {
	m: ClientMessage = msg
	s := prism.create_serializer(frame_arena_alloc)
	client_message_union_serialize(&s, &m)
	state.client.bytes_sent += i32(len(s.stream))
	fresnel.client_send_message(s.stream[:])
}
