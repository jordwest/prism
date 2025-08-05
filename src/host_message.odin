package main
import "core:reflect"
import "fresnel"
import "prism"

HostMessage :: union {
	HostMessageWelcome,
	HostMessageIdentifyResponse,
	HostMessageCursorPos,
	HostMessageEvent,
}

host_message_union_serialize :: proc(
	s: ^prism.Serializer,
	obj: ^HostMessage,
) -> prism.SerializationResult {
	state := prism.serialize_union_create(s, obj)
	prism.serialize_union_nil(0, &state)
	prism.serialize_union_variant(1, HostMessageWelcome, prism.serialize_empty, &state) or_return
	prism.serialize_union_variant(
		2,
		HostMessageIdentifyResponse,
		host_message_serialize_variant,
		&state,
	) or_return
	prism.serialize_union_variant(
		3,
		HostMessageCursorPos,
		host_message_serialize_variant,
		&state,
	) or_return
	prism.serialize_union_variant(
		4,
		HostMessageEvent,
		host_message_serialize_variant,
		&state,
	) or_return
	return prism.serialize_union_fail_if_not_found(&state)
}

@(private)
host_message_serialize_variant :: proc {
	cursor_pos_serialize,
	identify_response_serialize,
	event_serialize,
}

/************
 * Variants
 ***********/

HostMessageWelcome :: struct {}
HostMessageIdentifyResponse :: struct {
	player_id: PlayerId,
	entity_id: EntityId,
}
HostMessageCursorPos :: struct {
	player_id: PlayerId,
	pos:       [2]i32,
}
HostMessageEvent :: struct {
	event: Event,
}

@(private)
identify_response_serialize :: proc(
	s: ^prism.Serializer,
	msg: ^HostMessageIdentifyResponse,
) -> prism.SerializationResult {
	prism.serialize(s, (^i32)(&msg.player_id)) or_return
	prism.serialize(s, (^i32)(&msg.entity_id)) or_return
	return nil
}

@(private)
cursor_pos_serialize :: proc(
	s: ^prism.Serializer,
	msg: ^HostMessageCursorPos,
) -> prism.SerializationResult {
	prism.serialize(s, (^i32)(&msg.player_id)) or_return
	prism.serialize(s, &msg.pos) or_return
	return nil
}


@(private)
event_serialize :: proc(
	s: ^prism.Serializer,
	msg: ^HostMessageEvent,
) -> prism.SerializationResult {
	event_union_serialize(s, &msg.event) or_return
	return nil
}
