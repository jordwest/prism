package main

import "core:mem"
import "fresnel"
import "prism"

host_tick :: proc(dt: f32) {
	host_poll()
}

HostError :: union {
	mem.Allocator_Error,
}

host_boot :: proc() -> HostError {
	memory_init_host()
	context.allocator = host_arena_alloc

	alloc_error: mem.Allocator_Error

	game := state.client.game

	info("Size of game log %d", size_of(LogEntry) * 100_000)
	state.host.is_host = true
	state.host.game_log = make(
		[dynamic]LogEntry,
		0,
		100_000,
		allocator = host_arena_alloc,
	) or_return
	state.host.clients = make(map[ClientId]Client, 128, allocator = host_arena_alloc) or_return
	game.players = make(map[PlayerId]Player, 8, allocator = host_arena_alloc) or_return
	game.entities = make(map[EntityId]Entity, MAX_ENTITIES) or_return

	return nil
}

host_on_client_connected :: proc(clientId: ClientId) {
	host_send_message(clientId, HostMessageWelcome{})
	state.host.clients[clientId] = UnidentifiedClient{}
}

@(private)
host_poll :: proc() -> Error {
	msg_in := make([dynamic]u8, 1000, 1000, frame_arena_alloc)
	client_id: ClientId
	bytes_read := 0
	for {
		bytes_read := fresnel.server_poll_message((^i32)(&client_id), msg_in[:])
		if bytes_read <= 0 do break // No new messages
		state.host.bytes_received += bytes_read

		s := prism.create_deserializer(msg_in)
		msg: ClientMessage
		e := client_message_union_serialize(&s, &msg)
		if e != nil do return error(DeserializationError{result = e, offset = s.offset, data = msg_in[:bytes_read]})

		client, client_exists := &state.host.clients[client_id]
		if !client_exists do return error(ClientNotFound{client_id = client_id})
		client_ident, client_identified := client.(IdentifiedClient)

		if HOST_LOG_MESSAGES do info("[HOST] %w", msg)

		switch m in msg {
		case ClientMessageIdentify:
			state.client.game.newest_player_id += 1
			new_player_id := PlayerId(state.client.game.newest_player_id)

			client^ = IdentifiedClient {
				player_id = new_player_id,
				token     = m.token,
			}

			host_send_message(client_id, HostMessageIdentifyResponse{player_id = new_player_id})

			if int(m.next_log_seq) < len(state.host.game_log) {
				host_catch_up_client(client_id, m.next_log_seq)
			}

			host_log_entry(LogEntryPlayerJoined{player_id = new_player_id})
		case ClientMessageCursorPosUpdate:
			if !client_identified do break
			host_broadcast_message(
				HostMessageCursorPos{player_id = client_ident.player_id, pos = m.pos},
			)
		case ClientMessageSubmitCommand:
			if !client_identified do break
			host_log_entry(
				LogEntryCommand {
					player_id = client_ident.player_id,
					entity_id = m.entity_id,
					cmd = m.cmd,
				},
			)
			host_send_message(client_id, HostMessageCommandAck{cmd_seq = m.cmd_seq})
		}
	}
	return nil
}

host_send_message :: proc(client_id: ClientId, msg: HostMessage) {
	m: HostMessage = msg
	s := prism.create_serializer(frame_arena_alloc)
	host_message_union_serialize(&s, &m)
	state.host.bytes_sent += i32(len(s.stream))
	fresnel.server_send_message(i32(client_id), s.stream[:])
}

host_broadcast_message :: proc(msg: HostMessage) {
	m: HostMessage = msg
	s := prism.create_serializer(frame_arena_alloc)
	host_message_union_serialize(&s, &m)
	state.host.bytes_sent += i32(len(s.stream) * len(state.host.clients))
	fresnel.server_broadcast_message(s.stream[:])
}

host_log_entry :: proc(entry: LogEntry) {
	seq := LogSeqId(len(state.host.game_log))

	append(&state.host.game_log, entry)

	host_broadcast_message(HostMessageLogEntry{seq = seq, entry = entry})
}

host_catch_up_client :: proc(client_id: ClientId, start_at: LogSeqId) {
	total := len(state.host.game_log)
	for i := int(start_at); i < total; i += 1 {
		trace("Catching up from %d, send %d, %v", start_at, i, state.host.game_log[i])
		host_send_message(
			client_id,
			HostMessageLogEntry{entry = state.host.game_log[i], seq = LogSeqId(i), catchup = 1},
		)
	}
}
