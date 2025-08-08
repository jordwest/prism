package main
import "core:reflect"
import "fresnel"
import "prism"

@(private = "file")
S :: prism.Serializer
@(private = "file")
SResult :: prism.SerializationResult

HostMessage :: union {
	HostMessageWelcome,
	HostMessageIdentifyResponse,
	HostMessageCommandAck,
	HostMessageCursorPos,
	HostMessageLogEntry,
}

host_message_union_serialize :: proc(s: ^S, obj: ^HostMessage) -> SResult {
	state := prism.serialize_union_create(s, obj)
	prism.serialize_union_nil(0, &state)
	prism.serialize_union_variant(1, HostMessageWelcome, prism.serialize_empty, &state) or_return
	prism.serialize_union_variant(
		2,
		HostMessageIdentifyResponse,
		_serialize_variant,
		&state,
	) or_return
	prism.serialize_union_variant(
		3,
		HostMessageCommandAck,
		_serialize_command_ack,
		&state,
	) or_return
	prism.serialize_union_variant(4, HostMessageCursorPos, _serialize_variant, &state) or_return
	prism.serialize_union_variant(5, HostMessageLogEntry, _serialize_variant, &state) or_return
	return prism.serialize_union_fail_if_not_found(&state)
}

@(private = "file")
_serialize_variant :: proc {
	_cursor_pos_serialize,
	_identify_response_serialize,
	_serialize_command_ack,
	_log_entry_serialize,
}

/************
 * Variants
 ***********/

HostMessageWelcome :: struct {}

HostMessageIdentifyResponse :: struct {
	player_id: PlayerId,
}

@(private = "file")
_identify_response_serialize :: proc(s: ^S, msg: ^HostMessageIdentifyResponse) -> SResult {
	serialize(s, &msg.player_id) or_return
	return nil
}

HostMessageCommandAck :: struct {
	cmd_seq: CmdSeqId,
}

@(private = "file")
_serialize_command_ack :: proc(s: ^S, msg: ^HostMessageCommandAck) -> SResult {
	serialize(s, &msg.cmd_seq) or_return
	return nil
}

HostMessageCursorPos :: struct {
	player_id: PlayerId,
	pos:       TileCoord,
}

@(private = "file")
_cursor_pos_serialize :: proc(s: ^S, msg: ^HostMessageCursorPos) -> SResult {
	prism.serialize(s, (^i32)(&msg.player_id)) or_return
	prism.serialize(s, (^[2]i32)(&msg.pos)) or_return
	return nil
}

HostMessageLogEntry :: struct {
	seq:     LogSeqId,
	entry:   LogEntry,
	catchup: i32,
}

@(private = "file")
_log_entry_serialize :: proc(s: ^S, msg: ^HostMessageLogEntry) -> SResult {
	serialize(s, &msg.seq) or_return
	serialize(s, &msg.entry) or_return
	serialize(s, &msg.catchup) or_return
	return nil
}
