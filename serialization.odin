package main

import "binserial"
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

serialize_state :: proc(s: ^Serializer, state: ^TestStruct) -> SerializationResult {
	serialize_token(s, "S") or_return
	serialize_f32(s, &state.t) or_return
	serialize_token(s, "S") or_return
	serialize_u8(s, &state.test) or_return
	serialize_token(s, "S") or_return
	serialize_string(s, &state.greeting) or_return
	return nil
}

serialize_counter :: proc(s: ^Serializer) -> SerializationResult {
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
	serialize_counter(s)
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
