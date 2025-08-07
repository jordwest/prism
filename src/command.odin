package main

import "prism"

CommandTypeId :: enum u8 {
	None,
	Move,
	Attack,
}

Command :: struct {
	type:          CommandTypeId,
	pos:           TileCoord,
	target_entity: EntityId,
}

command_serialize :: proc(s: ^prism.Serializer, cmd: ^Command) -> prism.SerializationResult {
	prism.serialize(s, (^u8)(&cmd.type)) or_return
	prism.serialize(s, (^[2]i32)(&cmd.pos)) or_return
	prism.serialize(s, (^i32)(&cmd.target_entity)) or_return
	return nil
}

// Client-side command submission
command_submit :: proc(cmd: Command) {
	state.client._cmd_seq += 1
	if entity, ok := &state.client.common.entities[state.client.controlling_entity_id]; ok {
		entity._local_cmd = LocalCommand {
			cmd = cmd,
			seq = state.client._cmd_seq,
		}
		client_send_message(ClientMessageSubmitCommand{command = cmd, seq = state.client._cmd_seq})
	}
}
