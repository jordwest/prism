package prism

import "core:math"
import "core:mem"
import "core:slice"

SerializationResult :: enum byte {
	Success = 0,
	TokenMismatch,
	CounterMismatch,
	UnionVariantNotFound,
}

Serializer :: struct {
	stream:  []u8,
	offset:  i32,
	writing: bool,
	counter: u8,
}

create_serializer :: proc(buf: []u8) -> Serializer {
	return Serializer{stream = buf, offset = 0, writing = true}
}

create_deserializer :: proc(stream: []u8) -> Serializer {
	return Serializer{stream = stream, offset = 0, writing = false}
}

serialize_counter :: proc(s: ^Serializer) -> SerializationResult {
	s.counter += 1
	if (s.writing) {
		s.stream[s.offset] = s.counter
		// append(&s.stream, s.counter)
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
	if (s.writing) {
		s.stream[s.offset] = state^
		// append(&s.stream, state^)
	} else {
		state^ = s.stream[s.offset]
	}
	s.offset = s.offset + 1
	return nil
}

serialize_token :: proc(s: ^Serializer, token: string) -> SerializationResult {
	if (s.writing) {
		str_bytes := transmute([]u8)(token)
		mem.copy(&s.stream[s.offset], &str_bytes[0], len(str_bytes))
		// append(&s.stream, ..str_bytes[:])
	} else {
		str_slice := s.stream[s.offset:][:len(token)]
		if (string(str_slice) != token) {
			return SerializationResult.TokenMismatch
		}
	}
	s.offset = s.offset + i32(len(token))
	return nil
}

serialize_array :: proc(s: ^Serializer, arr: ^[$N]u8) -> SerializationResult {
	if (s.writing) {
		mem.copy(&s.stream[s.offset], &arr[0], len(arr))
	} else {
		str_slice := s.stream[s.offset:][:N]
		copy(arr[:], str_slice)
	}
	s.offset = s.offset + i32(len(arr^))
	return nil
}

serialize_string :: proc(s: ^Serializer, state: ^string) -> SerializationResult {
	// Counter not needed as its added by the serialize_i32 call
	if (s.writing) {
		str_len := i32(len(state^))
		serialize_i32(s, &str_len)

		str_bytes := transmute([]u8)(state^)
		mem.copy(&s.stream[s.offset], &str_bytes[0], len(str_bytes))
	} else {
		str_len: i32
		serialize_i32(s, &str_len)

		str_slice := s.stream[s.offset:][:str_len]
		state^ = string(str_slice)
	}
	s.offset = s.offset + i32(len(state^))
	return nil
}

serialize_bufstring :: proc(s: ^Serializer, bufstring: ^BufString($N)) -> SerializationResult {
	str_len: i32
	if (s.writing) {
		str_len = bufstring.len
		serialize_i32(s, &str_len)

		mem.copy(&s.stream[s.offset], &bufstring.buf[0], int(bufstring.len))
	} else {
		serialize_i32(s, &str_len)
		read_len := math.min(str_len, N)

		mem.copy(&bufstring.buf[0], &s.stream[s.offset], int(read_len))
		bufstring.len = read_len
	}
	s.offset = s.offset + str_len
	return nil
}

serialize_vec2i :: proc(s: ^Serializer, state: ^[2]i32) -> SerializationResult {
	serialize_i32(s, &state[0])
	serialize_i32(s, &state[1])
	return nil
}
serialize_i32 :: proc(s: ^Serializer, state: ^i32) -> SerializationResult {
	if (s.writing) {
		els := transmute([4]u8)(state^)
		mem.copy(&s.stream[s.offset], &els[0], len(els))
	} else {
		state^ = slice.to_type(s.stream[s.offset:][:4], i32)
	}
	s.offset = s.offset + 4
	return nil
}
serialize_u32 :: proc(s: ^Serializer, state: ^u32) -> SerializationResult {
	if (s.writing) {
		els := transmute([4]u8)(state^)
		mem.copy(&s.stream[s.offset], &els[0], len(els))
	} else {
		state^ = slice.to_type(s.stream[s.offset:][:4], u32)
	}
	s.offset = s.offset + 4
	return nil
}
serialize_u64 :: proc(s: ^Serializer, state: ^u64) -> SerializationResult {
	if (s.writing) {
		els := transmute([8]u8)(state^)
		mem.copy(&s.stream[s.offset], &els[0], len(els))
	} else {
		state^ = slice.to_type(s.stream[s.offset:][:8], u64)
	}
	s.offset = s.offset + 8
	return nil
}

serialize_f32 :: proc(s: ^Serializer, state: ^f32) -> SerializationResult {
	if (s.writing) {
		els := transmute([4]u8)(state^)
		mem.copy(&s.stream[s.offset], &els[0], len(els))
	} else {
		state^ = slice.to_type(s.stream[s.offset:][:4], f32)
	}
	s.offset = s.offset + 4
	return nil
}

UnionSerializerState :: struct($U: typeid) {
	serializer: ^Serializer,
	union_ref:  ^U,
	done:       bool,
}
serialize_union_create :: proc(s: ^Serializer, obj: ^$U) -> UnionSerializerState(U) {
	return UnionSerializerState(U){serializer = s, union_ref = obj}
}

serialize_union_nil :: proc(tag: u8, state: ^UnionSerializerState($U)) -> bool {
	if state.done {
		return false
	}
	if state.serializer.writing {
		if state.union_ref^ == nil {
			state.serializer.stream[state.serializer.offset] = tag
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

// Convenience function mostly for union types with no data
serialize_empty :: proc(_: ^Serializer, _: ^($T)) -> SerializationResult {
	return nil
}

serialize_union_fail_if_not_found :: proc(
	state: ^UnionSerializerState($U),
) -> SerializationResult {
	if !state.done {
		return SerializationResult.UnionVariantNotFound
	}
	return nil
}

serialize_union_variant :: proc(
	tag: u8,
	$T: typeid,
	serializer: proc(s: ^Serializer, t: ^T) -> SerializationResult,
	state: ^UnionSerializerState($U),
) -> SerializationResult {
	if state.done {
		return nil
	}

	if state.serializer.writing {
		variant, ok := state.union_ref.(T)
		if ok {
			state.serializer.stream[state.serializer.offset] = tag
			state.serializer.offset += 1
			// serialize_empty is not baked into the code due to being polymorphic
			// so it ends up being a null pointer, which we check for here.
			// Would be nice to find a better way but this hack works for now
			if serializer != nil {
				serializer(state.serializer, &variant) or_return
			}
			state.done = true
			return nil
		}
	} else {
		read_tag: u8 = state.serializer.stream[state.serializer.offset]
		if read_tag == tag {
			state.serializer.offset += 1
			t: T
			if serializer != nil {
				serializer(state.serializer, &t) or_return
			}
			state.union_ref^ = t
			state.done = true
			return nil
		}
	}

	return nil
}

serialize :: proc {
	serialize_vec2i,
	serialize_i32,
	serialize_array,
	serialize_f32,
	serialize_u8,
	serialize_string,
	serialize_bufstring,
}
