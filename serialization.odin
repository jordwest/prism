package prism

import "base:intrinsics"
import "core:encoding/endian"
import "core:math"
import "core:mem"
import "core:fmt"

SerializationResult :: enum byte {
	Success = 0,
	StringLiteralMismatch,
	EndOfStream,
	UnionVariantNotFound,
	ParseError,
}

SerializeMode :: enum {
	Binary = 0,
	Text = 1,
}

Serializer :: struct {
	stream:  []u8,
	indent: u8,
	offset:  int,
	writing: bool,
	version: i32,
	mode: SerializeMode,
	trace_fn: Maybe(proc(string, ..any)),
}

create_serializer :: proc(buf: []u8, mode: SerializeMode = .Binary, trace: Maybe(proc(f: string, args: ..any)) = nil) -> Serializer {
	return Serializer{stream = buf, offset = 0, writing = true, mode = mode, trace_fn = trace}
}

create_deserializer :: proc(stream: []u8, mode: SerializeMode = .Binary, trace: Maybe(proc(f: string, args: ..any)) = nil) -> Serializer {
	return Serializer{stream = stream, offset = 0, writing = false, mode = mode, trace_fn = trace}
}

serialize_version :: proc(s: ^Serializer, serialize_version: i32) -> SerializationResult {
	if s.mode == .Text {
		serialize_string_literal(s, "version=") or_return
	}

	s.version = serialize_version
	serialize_i32(s, &s.version) or_return

	return nil
}

@(private = "file")
_trace :: proc(s: ^Serializer, fstr: string, args: ..any) {
	// i
	fn, ok := s.trace_fn.?
	if ok do fn(fstr, ..args)
}

serialize_string_literal :: proc(s: ^Serializer, literal: string) -> SerializationResult {
	if (s.writing) {
		fmt.bprintf(s.stream[s.offset:], "%s", literal)
	} else {
		str_slice := s.stream[s.offset:][:len(literal)]
		if (string(str_slice) != literal) {
			_trace(s, "Expecting: '%s', got '%s' at %d", literal, string(str_slice), s.offset)
			return SerializationResult.StringLiteralMismatch
		}
	}
	s.offset = s.offset + len(literal)
	return nil
}

serialize_newline :: proc(s: ^Serializer) -> SerializationResult {
	if s.mode != .Text do return nil

	serialize_string_literal(s, "\n") or_return
	for i : u8 = 0; i < s.indent; i += 1 {
		serialize_string_literal(s, "| ") or_return
	}

	return nil
}

serialize_dynamic_array :: proc(s: ^Serializer, arr: ^[dynamic]$T, serializer: proc(^Serializer, ^T) -> SerializationResult) -> SerializationResult {
	length: i32

	if s.mode == .Text {
		serialize_string_literal(s, "len=")
	}
	if s.writing {
		length = i32(len(arr))
		serialize_i32(s, &length) or_return
	} else {
		serialize_i32(s, &length) or_return
		resize(arr, length)
	}

	s.indent += 1
	if s.mode == .Text {
		serialize_string_literal(s, "[")
	}
	for i : i32 = 0; i < length; i += 1 {
		serializer(s, &arr[i]) or_return
	}
	if s.mode == .Text {
		serialize_string_literal(s, "]")
	}
	s.indent -= 1

	return nil
}

serialize_fixed_array :: proc(s: ^Serializer, arr: ^[$N]$T, serializer: proc(^Serializer, ^T) -> SerializationResult) -> SerializationResult {
	for i := 0; i < N; i += 1 {
		serializer(s, &arr[i]) or_return
	}

	return nil
}

serialize_string :: proc(s: ^Serializer, state: ^string) -> SerializationResult {
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
	s.offset = s.offset + len(state^)
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

serialize_endian :: proc(
	s: ^Serializer,
	state: ^$T,
	writer: proc "contextless" ([]byte, endian.Byte_Order, T) -> bool,
	reader: proc "contextless" ([]byte, endian.Byte_Order) -> (T, bool)
) -> SerializationResult {
	size := size_of(T)
	if (s.writing) {
		writer(s.stream[s.offset:], .Little, state^)
	} else {
		read_val, ok := reader(s.stream[s.offset:], .Little)
		if (!ok) do return SerializationResult.EndOfStream
		state^ = read_val
	}

	s.offset = s.offset + size
	return nil
}

serialize_byte :: proc(s: ^Serializer, state: ^byte) -> SerializationResult {
	if (s.writing) {
		s.stream[s.offset] = state^
	} else {
		state^ = s.stream[s.offset]
	}
	s.offset = s.offset + 1
	return nil
}

serialize_maybe :: proc(s: ^Serializer, state: ^Maybe($T), child_serializer: proc(s: ^Serializer, state: ^T) -> SerializationResult) -> SerializationResult {
	if s.writing {
		if v, ok := state.?; ok {
			child_serializer(s, &v) or_return
		} else {
			serialize_string_literal(s, "!") or_return
		}
	} else {
		if serialize_string_literal(s, "!") == .StringLiteralMismatch {
			// Not null, read the value
			v: T
			child_serializer(s, &v) or_return
		} else {
			state^ = nil
		}
	}
	return nil
}

serialize_u8_b :: serialize_byte
serialize_i8_b :: proc(s: ^Serializer, state: ^i8) -> SerializationResult { return serialize_byte(s, (^byte)(state)) }
serialize_i32_b :: proc(s: ^Serializer, state: ^i32) -> SerializationResult { return serialize_endian(s, state, endian.put_i32, endian.get_i32) }
serialize_u32_b :: proc(s: ^Serializer, state: ^u32) -> SerializationResult { return serialize_endian(s, state, endian.put_u32, endian.get_u32) }
serialize_u64_b :: proc(s: ^Serializer, state: ^u64) -> SerializationResult { return serialize_endian(s, state, endian.put_u64, endian.get_u64) }
serialize_f32_b :: proc(s: ^Serializer, state: ^f32) -> SerializationResult { return serialize_endian(s, state, endian.put_f32, endian.get_f32) }

serialize_u32 :: proc(s: ^Serializer, state: ^u32) -> SerializationResult {
	if s.mode == .Binary do return serialize_endian(s, state, endian.put_u32, endian.get_u32)
	return serialize_num_text(s, state, u64, parse_u)
}
serialize_i32 :: proc(s: ^Serializer, state: ^i32) -> SerializationResult {
	if s.mode == .Binary do return serialize_endian(s, state, endian.put_i32, endian.get_i32)
	return serialize_num_text(s, state, i64, parse_i)
}
serialize_i8 :: proc(s: ^Serializer, state: ^i8) -> SerializationResult {
	if s.mode == .Binary do return serialize_byte(s, (^byte)(state))
	return serialize_num_text(s, state, i64, parse_i)
}
serialize_u8 :: proc(s: ^Serializer, state: ^u8) -> SerializationResult {
	if s.mode == .Binary do return serialize_byte(s, state)
	return serialize_num_text(s, state, u64, parse_u)
}
serialize_f32 :: proc(s: ^Serializer, state: ^f32) -> SerializationResult {
	if s.mode == .Binary do return serialize_endian(s, state, endian.put_f32, endian.get_f32)
	return serialize_num_text(s, state, f64, parse_f)
}

serialize_num_text :: proc(s: ^Serializer, state: ^($T), $P: typeid, parser: proc(state: ParserState) -> (ParserState, P, ParserError)) -> SerializationResult {
	if (s.writing) {
		fmtstr := intrinsics.type_is_float(T) ? "%f," : "%d,"
		text := fmt.bprintf(s.stream[s.offset:], fmtstr, state^)
		s.offset = s.offset + len(text)
	} else {
		pstate, perr := parse_init(string(s.stream[s.offset:]))
		pstate.trace_fn = s.trace_fn
		parsed: P
		pstate, parsed, perr = parser(pstate)
		if perr != .Ok {
			_trace(s, "Failed to parse number at %d in '%s'", pstate.offset, pstate.input)
			return .ParseError
		}
		pstate, _, perr = parse_rune(pstate, ',')
		if perr != .Ok do return .ParseError
		state^ = T(parsed)
		s.offset = s.offset + pstate.offset
	}
	return nil
}

UnionSerializerState :: struct($U: typeid) {
	serializer: ^Serializer,
	union_ref:  ^U,
	done:       bool,
	tag: u8,
}

serialize_union :: proc(s: ^Serializer, obj: ^$U, f: proc(state: ^UnionSerializerState(U)) -> SerializationResult) -> SerializationResult {
	state := UnionSerializerState(U){serializer = s, union_ref = obj}

	text_prefix := "variant="
	if state.serializer.mode == .Text {
		serialize_string_literal(state.serializer, text_prefix)
	}

	// When reading, we want to preemptively fetch the variant tag, so it can be efficiently compared to each variant
	if !s.writing {
		serialize_u8(s, &state.tag) or_return
	}

	serialize_union_nil(0, &state)

	// Serialize each variant
	f(&state) or_return

	if !state.done {
		return SerializationResult.UnionVariantNotFound
	}
	return nil
}

serialize_union_nil :: proc(tag: u8, state: ^UnionSerializerState($U)) -> bool {
	if state.done {
		return false
	}
	if state.serializer.writing {
		if state.union_ref^ == nil {
			tag_local := tag
			serialize_u8(state.serializer, &tag_local)
			state.done = true
			return true
		}
	} else {
		// Tag already read, just compare
		if state.tag == tag {
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
			tag_local := tag
			serialize_u8(state.serializer, &tag_local)
			// serialize_empty is not baked into the code due to being polymorphic
			// so it ends up being a null pointer, which we check for here.
			// Would be nice to find a better way but this hack works for now
			if serializer != nil {
				state.serializer.indent += 1
				serializer(state.serializer, &variant) or_return
				state.serializer.indent -= 1
			}
			state.done = true
			return nil
		}
	} else {
		// Tag already read, just compare
		if state.tag == tag {
			t: T
			if serializer != nil {
				state.serializer.indent += 1
				serializer(state.serializer, &t) or_return
				state.serializer.indent -= 1
			}
			state.union_ref^ = t
			state.done = true
			return nil
		}
	}

	return nil
}

serialize :: proc {
	serialize_i32,
	serialize_fixed_array,
	serialize_f32,
	serialize_u8,
	serialize_string,
	serialize_bufstring,
}
