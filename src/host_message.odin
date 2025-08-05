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
		_serialize_variant,
		&state,
	) or_return
	prism.serialize_union_variant(3, HostMessageCursorPos, _serialize_variant, &state) or_return
	prism.serialize_union_variant(4, HostMessageEvent, _serialize_variant, &state) or_return
	return prism.serialize_union_fail_if_not_found(&state)
}

@(private = "file")
_serialize_variant :: proc {
	_cursor_pos_serialize,
	_identify_response_serialize,
	_event_serialize,
}

/************
 * Variants
 ***********/

HostMessageWelcome :: struct {}

HostMessageIdentifyResponse :: struct {
	player_id: PlayerId,
	entity_id: EntityId,
}

@(private = "file")
_identify_response_serialize :: proc(
	s: ^prism.Serializer,
	msg: ^HostMessageIdentifyResponse,
) -> prism.SerializationResult {
	prism.serialize(s, (^i32)(&msg.player_id)) or_return
	prism.serialize(s, (^i32)(&msg.entity_id)) or_return
	return nil
}

HostMessageCursorPos :: struct {
	player_id: PlayerId,
	pos:       [2]i32,
}

@(private = "file")
_cursor_pos_serialize :: proc(
	s: ^prism.Serializer,
	msg: ^HostMessageCursorPos,
) -> prism.SerializationResult {
	prism.serialize(s, (^i32)(&msg.player_id)) or_return
	prism.serialize(s, &msg.pos) or_return
	return nil
}

HostMessageEvent :: struct {
	event: Event,
}

@(private = "file")
_event_serialize :: proc(
	s: ^prism.Serializer,
	msg: ^HostMessageEvent,
) -> prism.SerializationResult {
	event_union_serialize(s, &msg.event) or_return
	return nil
}
