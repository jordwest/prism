package prism

import "core:strconv"
import "core:unicode/utf8"

ParserState :: struct {
	offset: int,
	input: string,
	trace_fn: Maybe(proc(string, ..any)),
}

ParserError :: enum {
	Ok = 0,
	InvalidToken,
	ConversionFailed,
	EndOfString,
}

@(private = "file")
_trace :: proc(s: ParserState, fmtstr: string, args: ..any) {
	if t, ok := s.trace_fn.?; ok {
		t(fmtstr, args)
	}
}

parse_init :: proc(input: string) -> (ParserState, ParserError) {
	return {
		offset = 0,
		input = input,
	}, .Ok
}

parse_i :: proc(state: ParserState) -> (pstate: ParserState, out: i64, perr: ParserError) {
	pstate = state
	out_str: string

	pstate, out_str = parse_numeric(pstate) or_return
	out_i64, ok := strconv.parse_i64_of_base(out_str, 10)
	if !ok do return pstate, 0, .ConversionFailed

	return pstate, out_i64, .Ok
}
parse_u :: proc(state: ParserState) -> (pstate: ParserState, out: u64, perr: ParserError) {
	pstate = state
	out_str: string

	pstate, out_str = parse_numeric(pstate) or_return
	out_u64, ok := strconv.parse_u64_of_base(out_str, 10)
	if !ok do return pstate, 0, .ConversionFailed

	return pstate, out_u64, .Ok
}
parse_f :: proc(state: ParserState) -> (pstate: ParserState, out: f64, perr: ParserError) {
	pstate = state
	out_str: string

	pstate, out_str = parse_numeric(pstate) or_return

	out_f64, ok := strconv.parse_f64(out_str)
	if !ok do return pstate, 0, .ConversionFailed

	return pstate, out_f64, .Ok
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

parse_rune :: proc(state: ParserState, expected: rune) -> (ParserState, rune, ParserError) {
	c := utf8.rune_at(state.input, state.offset)
	rune_size := utf8.rune_size(c)

	if (expected == c) {
		return parse_inc_offset(state, rune_size), c, .Ok
	}
	return state, 0, .InvalidToken
}

parse_digit :: proc(state: ParserState) -> (ParserState, rune, ParserError) {
	c := utf8.rune_at(state.input, state.offset)
	rune_size := utf8.rune_size(c)
	if (c >= '0' && c <= '9') || c == '.' || c == '-' {
		return parse_inc_offset(state, rune_size), c, .Ok
	}
	return state, 0, .InvalidToken
}
