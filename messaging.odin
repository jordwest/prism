package main
import "core:reflect"
import "fresnel"

ClientMessageCursorPosUpdate :: struct {
	pos: [2]i32,
}

@(private)
serialize_client_message_cursor_pos_update :: proc(
	s: ^Serializer,
	msg: ^ClientMessageCursorPosUpdate,
) -> SerializationResult {
	serialize(s, &msg.pos) or_return
	return nil
}

ClientMessage :: union {
	ClientMessageCursorPosUpdate,
	i32,
}

UnionVariantSerializeState :: struct($U: typeid) {
	serializer: ^Serializer,
	union_ref:  ^U,
	done:       bool,
}
serialize_union_create :: proc(s: ^Serializer, obj: ^$U) -> UnionVariantSerializeState(U) {
	return UnionVariantSerializeState(ClientMessage){serializer = s, union_ref = obj}
}

serialize_client_message :: proc(s: ^Serializer, obj: ^ClientMessage) {
	state := serialize_union_create(s, obj)
	serialize_union_nil(0, &state)
	serialize_union_variant(1, ClientMessageCursorPosUpdate, serialize_apptype, &state)
	serialize_union_variant(2, i32, serialize, &state)
}

serialize_apptype :: proc {
	serialize_client_message_cursor_pos_update,
	serialize_client_message,
}
