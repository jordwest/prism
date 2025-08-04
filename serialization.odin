package main

import "core:mem"
import "core:slice"

SerializationResult :: enum {
	Success,
	TokenMismatch,
	CounterMismatch,
}

Serializer :: struct {
	stream:  [dynamic]u8,
	offset:  i32,
	writing: bool,
	counter: u8,
}

create_serializer :: proc(alloc: mem.Allocator = context.allocator) -> Serializer {
	stream := make([dynamic]u8, 0, 20, alloc)
	return Serializer{stream = stream, offset = 0, writing = true}
}

create_deserializer :: proc(stream: [dynamic]u8) -> Serializer {
	return Serializer{stream = stream, offset = 0, writing = false}
}


serialize_state :: proc(s: ^Serializer, state: ^GameState) -> SerializationResult {
	serialize(s, &state.t) or_return
	serialize(s, &state.test) or_return
	serialize(s, &state.greeting) or_return
	return nil
}

serialize_counter :: proc(s: ^Serializer) -> SerializationResult {
	serialize_token(s, "[") or_return
	s.counter += 1
	if (s.writing) {
		append(&s.stream, s.counter)
	} else {
		counter := s.stream[s.offset]
		if (counter != s.counter) {
			return SerializationResult.CounterMismatch
		}
	}
	s.offset = s.offset + 1
	serialize_token(s, "]") or_return
	return nil
}

serialize_u8 :: proc(s: ^Serializer, state: ^u8) -> SerializationResult {
	serialize_counter(s)
	if (s.writing) {
		append(&s.stream, state^)
	} else {
		state^ = s.stream[s.offset]
	}
	s.offset = s.offset + 1
	return SerializationResult.Success
}

serialize_token :: proc(s: ^Serializer, token: string) -> SerializationResult {
	if (s.writing) {
		str_bytes := transmute([]u8)(token)
		append(&s.stream, ..str_bytes[:])
	} else {
		str_slice := s.stream[s.offset:][:len(token)]
		if (string(str_slice) != token) {
			return SerializationResult.TokenMismatch
		}
	}
	s.offset = s.offset + i32(len(token))
	return SerializationResult.Success
}

serialize_string :: proc(s: ^Serializer, state: ^string) -> SerializationResult {
	// Counter not needed as its added by the serialize_i32 call
	if (s.writing) {
		str_len := i32(len(state^))
		serialize_i32(s, &str_len)

		str_bytes := transmute([]u8)(state^)
		append(&s.stream, ..str_bytes[:])
	} else {
		str_len: i32
		serialize_i32(s, &str_len)

		str_slice := s.stream[s.offset:][:str_len]
		state^ = string(str_slice)
	}
	s.offset = s.offset + i32(len(state^))
	return SerializationResult.Success
}

serialize_vec2i :: proc(s: ^Serializer, state: ^[2]i32) -> SerializationResult {
	serialize_counter(s)
	serialize_i32(s, &state[0])
	serialize_i32(s, &state[1])
	return nil
}
serialize_i32 :: proc(s: ^Serializer, state: ^i32) -> SerializationResult {
	serialize_counter(s)
	if (s.writing) {
		els := transmute([4]u8)(state^)
		append(&s.stream, ..els[:])
	} else {
		state^ = slice.to_type(s.stream[s.offset:][:4], i32)
	}
	s.offset = s.offset + 4
	return nil
}

serialize_f32 :: proc(s: ^Serializer, state: ^f32) -> SerializationResult {
	serialize_counter(s)
	if (s.writing) {
		els := transmute([4]u8)(state^)
		append(&s.stream, ..els[:])
	} else {
		state^ = slice.to_type(s.stream[s.offset:][:4], f32)
	}
	s.offset = s.offset + 4
	return nil
}

serialize_union_variant :: proc(
	tag: u8,
	$T: typeid,
	serializer: proc(s: ^Serializer, t: ^T) -> SerializationResult,
	state: ^UnionVariantSerializeState($U),
) -> bool {
	if state.done {
		return false
	}

	if state.serializer.writing {
		variant, ok := state.union_ref.(T)
		if ok {
			append(&state.serializer.stream, tag)
			serializer(state.serializer, &variant)
			state.done = true
			return true
		}
	} else {
		read_tag: u8 = state.serializer.stream[state.serializer.offset]
		if read_tag == tag {
			state.serializer.offset += 1
			t: T
			serializer(state.serializer, &t)
			state.union_ref^ = t
			state.done = true
			return true
		}
	}

	return false
}

serialize :: proc {
	serialize_vec2i,
	serialize_i32,
	serialize_f32,
	serialize_u8,
	serialize_string,
}
