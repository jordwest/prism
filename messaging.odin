package main
import "core:reflect"
import "fresnel"

ClientMessageCursorPosUpdate :: struct {
	pos: [2]i32,
}

@(private)
sz_cm_cursor_pos_update :: proc(
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


serialize_union_nil :: proc(tag: u8, state: ^UnionVariantSerializeState($U)) -> bool {
	if state.done {
		return false
	}
	fresnel.info("Trying nil")
	if state.serializer.writing {
		if state.union_ref^ == nil {
			append(&state.serializer.stream, tag)
			state.done = true
			return true
		}
	} else {
		read_tag: u8 = state.serializer.stream[state.serializer.offset]
		if read_tag == tag {
			state.serializer.offset += 1
			state.union_ref^ = nil
			state.done = true
			return true
		}
	}

	return false
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
	sz_cm_cursor_pos_update,
	serialize_client_message,
}
