package prism

import "core:strconv"
import "core:strings"
import "base:runtime"
import "core:unicode/utf8"
import "core:encoding/endian"
import "core:math"
import "core:mem"
import "core:slice"
import "core:fmt"

SerializationResult :: enum byte {
	Success = 0,
	TokenMismatch,
	CounterMismatch,
	EndOfStream,
	UnionVariantNotFound,
	ParseError,
}

Serializer :: struct {
	stream:  []u8,
	offset:  i32,
	writing: bool,
	version: i32,
	counter: u8,
}

create_serializer :: proc(buf: []u8) -> Serializer {
	return Serializer{stream = buf, offset = 0, writing = true}
}

create_deserializer :: proc(stream: []u8) -> Serializer {
	return Serializer{stream = stream, offset = 0, writing = false}
}

serialize_version :: proc(s: ^Serializer, serialize_version: i32) -> SerializationResult {
	if (s.writing) {
		endian.put_i32(s.stream[s.offset:], .Big, serialize_version)
		s.version = serialize_version
	} else {
		read_version, ok := endian.get_i32(s.stream[s.offset:], .Big)
		if (!ok) do return SerializationResult.EndOfStream
		s.version = read_version
	}
	s.offset += 4
	return nil
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

serialize_u32_text :: proc(s: ^Serializer, state: ^u32) -> SerializationResult {
	if (s.writing) {
		text := fmt.tprintf("%d", state^)

		str_bytes := transmute([]u8)(text)
		mem.copy(&s.stream[s.offset], &str_bytes[0], len(str_bytes))

		s.offset = s.offset + i32(len(text))
	} else {
		pstate, perr := parse_init(string(s.stream[s.offset:]))
		parsed: u32
		_, parsed, perr = parse_u32(pstate)
		if perr != .Ok do return .ParseError
		state^ = parsed
		s.offset = s.offset + i32(pstate.offset)
	}
	return nil
}

ParserState :: struct {
	offset: int,
	input: string,
}

ParserError :: enum {
	Ok = 0,
	InvalidToken,
	ConversionFailed,
	EndOfString,
}

parse_init :: proc(input: string) -> (ParserState, ParserError) {
	return {
		offset = 0,
		input = input,
	}, .Ok
}

parse_u32 :: proc(state: ParserState) -> (pstate: ParserState, out: u32, perr: ParserError) {
	pstate = state
	out_str: string

	pstate, out_str = parse_numeric(pstate) or_return

	out_u64, ok := strconv.parse_u64_of_base(out_str, 10)
	if !ok do return pstate, 0, .ConversionFailed

	return pstate, u32(out_u64), .Ok
}

parse_numeric :: proc(state: ParserState) -> (ParserState, string, ParserError) {
	perr := ParserError.Ok
	pstate := state
	start := state.offset
	c: rune

	for {
		pstate, c, perr = parse_digit(pstate)
		if perr != .Ok do break
	}

	if pstate.offset == start do return pstate, "", perr

	return pstate, state.input[start:pstate.offset], .Ok
}

parse_inc_offset :: proc(state: ParserState, increment_by: int) -> ParserState {
	s := state
	s.offset += increment_by
	return s
}

parse_digit :: proc(state: ParserState) -> (ParserState, rune, ParserError) {
	c := utf8.rune_at(state.input, state.offset)
	rune_size := utf8.rune_size(c)
	if (c >= '0' && c <= '9') || c == '.' {
		return parse_inc_offset(state, rune_size), c, .Ok
	}
	return state, 0, .InvalidToken
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
serialize_union_start :: proc(s: ^Serializer, obj: ^$U) -> UnionSerializerState(U) {
	return UnionSerializerState(U){serializer = s, union_ref = obj}
}
serialize_union :: proc(s: ^Serializer, obj: ^$U, f: proc(state: ^UnionSerializerState(U)) -> SerializationResult) -> SerializationResult {
	state := serialize_union_start(s, obj)
	serialize_union_nil(0, &state)
	f(&state) or_return
	return serialize_union_end(&state)
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

serialize_union_end :: proc(
	state: ^UnionSerializerState($U),
) -> SerializationResult {
	if !state.done {
		return SerializationResult.UnionVariantNotFound
	}
	return nil
}

serialize_variant :: proc(
	state: ^UnionSerializerState($U),
	tag: u8,
	// $T: typeid,
	serializer: proc(s: ^Serializer, t: ^$T) -> SerializationResult,
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
