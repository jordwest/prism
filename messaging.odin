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

test_union_ser :: proc() {
	msg: ClientMessage = ClientMessageCursorPosUpdate {
		pos = {8, 9},
	}
	msg2: ClientMessage = 23
	msg3: ClientMessage

	s := create_serializer(frame_arena_alloc)
	serialize_client_message(&s, &msg2)
	serialize_client_message(&s, &msg)
	serialize_client_message(&s, &msg3)

	fresnel.log_slice("serialized union", s.stream[:])

	de := create_deserializer(s.stream)

	for i := 0; i < 3; i += 1 {
		deserialized_message: ClientMessage
		serialize_client_message(&de, &deserialized_message)
		switch m in deserialized_message {
		case nil:
			err("Nil")
		case i32:
			info("i32 %d", m)
		case ClientMessageCursorPosUpdate:
			info("cursor pos %v", m)
		}
	}
}

serialize_union_nil :: proc(tag: u8, state: ^UnionVariantSerializeState($U)) -> bool {
	if state.done {
		return false
	}
	info("Trying nil")
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
