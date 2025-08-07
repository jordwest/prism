package main

import "core:mem"
import "fresnel"
import "prism"

host_tick :: proc(dt: f32) {
	host_poll()

	if pcg, ok := state.host.pcg.?; ok {
		max_iterations := PCG_ITERATION_DELAY == 0 ? 100 : 1
		t0 := fresnel.now()
		for i := 0; i < max_iterations && !pcg.done; i += 1 {
			procgen_iterate(pcg)
		}
		t1 := fresnel.now()
		pcg.total_time += (t1 - t0)

		// TODO: This is just a test for visualisation purposes for now
		prism.djikstra_clear(&pcg.djikstra_map)
		// prism.djikstra_add_origin(&pcg.djikstra_map, Vec2i(state.client.cursor_pos))
		prism.djikstra_add_origin(&pcg.djikstra_map, Vec2i(state.host.spawn_point))
		prism.djikstra_iterate(&pcg.djikstra_map)

		current_cost := pcg.djikstra_map.max_cost
		path := make([dynamic]([2]i32), 0, int(current_cost), allocator = context.temp_allocator)

		// Path to origin
		for pos := pcg.djikstra_map.max_cost_coord; pos != Vec2i(state.host.spawn_point); {
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
		prism.djikstra_iterate(&pcg.djikstra_map)

		fresnel.metric_i32("djikstra_iterations", pcg.djikstra_map.iterations)
	}
}

HostError :: union {
	mem.Allocator_Error,
}

host_boot :: proc() -> HostError {
	memory_init_host()
	context.allocator = host_arena_alloc

	alloc_error: mem.Allocator_Error

	state.host.is_host = true
	state.host.clients = make(map[i32]Client, 128, allocator = host_arena_alloc) or_return
	state.host.common.players = make(
		map[PlayerId]Player,
		8,
		allocator = host_arena_alloc,
	) or_return
	state.host.common.entities = make(map[EntityId]Entity, MAX_ENTITIES) or_return

	state.debug.render_host_state = DEFAULT_DEBUG_RENDER_HOST_STATE

	pcg := new(PcgState)
	state.host.pcg = pcg
	procgen_init(pcg)

	return nil
}

host_on_client_connected :: proc(clientId: i32) {
	host_send_message(clientId, HostMessageWelcome{})

	state.host.clients[clientId] = Client{}

	// TODO: Just send the whole state instead
	for _, e in state.host.common.entities {
		host_broadcast_message(HostMessageEvent{event = EventEntitySpawned{entity = e}})
	}
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
		state.bytes_received += bytes_read

		s := prism.create_deserializer(msg_in)
		msg: ClientMessage
		e := client_message_union_serialize(&s, &msg)

		if e != nil {
			err("Failed to deserialize %v", e)
		}

		client, client_exists := state.host.clients[client_id]
		player, player_exists := state.host.common.players[client.player_id]
		switch m in msg {
		case ClientMessageIdentify:
			state.host.newest_player_id += 1
			new_player_id := PlayerId(state.host.newest_player_id)

			player_entity := host_spawn_entity(EntityMetaId.Player)
			player_entity.pos = {2, 5}
			player_entity.player_id = new_player_id

			state.host.common.players[new_player_id] = Player {
				player_id        = new_player_id,
				player_entity_id = player_entity.id,
				_token           = m.token,
			}

			if client, ok := &state.host.clients[client_id]; ok {
				client.player_id = new_player_id
			}

			host_send_message(
				client_id,
				HostMessageIdentifyResponse {
					player_id = new_player_id,
					entity_id = player_entity.id,
				},
			)

			host_broadcast_message(
				HostMessageEvent {
					event = EventPlayerJoined {
						player_id = new_player_id,
						player_entity_id = player_entity.id,
					},
				},
			)
		case ClientMessageCursorPosUpdate:
			if player_exists {
				host_broadcast_message(
					HostMessageCursorPos{player_id = client.player_id, pos = m.pos},
				)
			}
		case ClientMessageSubmitCommand:
			entity := &state.host.common.entities[player.player_entity_id]
			entity.pos = m.command.pos
			entity.cmd = m.command
			host_broadcast_message(
				HostMessageEvent {
					event = EventEntityMoved{entity_id = entity.id, pos = m.command.pos},
				},
			)
			host_broadcast_message(
				HostMessageEvent {
					event = EventEntityCommandChanged {
						entity_id = entity.id,
						// cmd = entity.cmd,
						cmd       = Command{},
						seq       = m.seq,
					},
				},
			)
		}

		if HOST_LOG_MESSAGES do info("[HOST] %w", msg)
	}
}

host_send_message :: proc(clientId: i32, msg: HostMessage) {
	m: HostMessage = msg
	s := prism.create_serializer(frame_arena_alloc)
	host_message_union_serialize(&s, &m)
	state.bytes_sent += len(s.stream)
	fresnel.server_send_message(clientId, s.stream[:])
}

host_broadcast_message :: proc(msg: HostMessage) {
	m: HostMessage = msg
	s := prism.create_serializer(frame_arena_alloc)
	host_message_union_serialize(&s, &m)
	state.bytes_sent += len(s.stream)
	fresnel.server_broadcast_message(s.stream[:])
}

host_spawn_entity :: proc(meta_id: EntityMetaId) -> ^Entity {
	state.host.newest_entity_id += 1
	id := EntityId(state.host.newest_entity_id)

	new_entity := Entity {
		id      = id,
		meta_id = meta_id,
	}
	state.host.common.entities[id] = new_entity
	host_broadcast_message(HostMessageEvent{event = EventEntitySpawned{entity = new_entity}})

	return &state.host.common.entities[id]
}
