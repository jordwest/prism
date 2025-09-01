package main

import "core:reflect"
import "fresnel"
import "prism"

ClientMessage :: union {
	ClientMessageIdentify,
	ClientMessageSubmitCommand,
}

client_message_union_serialize :: proc(
	s: ^prism.Serializer,
	obj: ^ClientMessage,
) -> prism.SerializationResult {
	state := prism.serialize_union_create(s, obj)
	prism.serialize_union_nil(0, &state)
	prism.serialize_union_variant(1, ClientMessageIdentify, serialize_variant, &state) or_return
	prism.serialize_union_variant(
		2,
		ClientMessageSubmitCommand,
		serialize_variant,
		&state,
	) or_return
	return prism.serialize_union_fail_if_not_found(&state)
}

@(private)
serialize_variant :: proc {
	_identify_serialize,
	_submit_command_serialize,
}

/************
 * Variants
 ***********/

JoinMode :: enum u8 {
	Play,
	Spectate,
}

ClientMessageIdentify :: struct {
	token:        PlayerToken,
	join_mode:    JoinMode,
	display_name: prism.BufString(32),
	next_log_seq: LogSeqId,
}

@(private)
_identify_serialize :: proc(
	s: ^prism.Serializer,
	msg: ^ClientMessageIdentify,
) -> prism.SerializationResult {
	prism.serialize(s, &msg.token) or_return
	prism.serialize(s, (^u8)(&msg.join_mode)) or_return
	prism.serialize(s, &msg.display_name) or_return
	return nil
}

ClientMessageSubmitCommand :: struct {
	entity_id: EntityId,
	cmd_seq:   CmdSeqId,
	cmd:       Command,
}

@(private)
_submit_command_serialize :: proc(
	s: ^prism.Serializer,
	msg: ^ClientMessageSubmitCommand,
) -> prism.SerializationResult {
	serialize(s, &msg.entity_id) or_return
	serialize(s, &msg.cmd_seq) or_return
	serialize(s, &msg.cmd) or_return
	return nil
}
