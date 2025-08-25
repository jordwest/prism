package prism

import "core:mem"

BufString :: struct($N: i32) {
	buf: [N]u8,
	len: i32,
}

bufstring_update_from_string :: proc(bs: ^BufString($N), str: string) {
	copy(bs.buf[:], str)
	bs.len = i32(len(str))
}

bufstring_from_string :: proc($N: i32, str: string) -> BufString(N) {
	bs := BufString(N){}
	bufstring_update_from_string(&bs, str)
	return bs
}

bufstring_as_str :: proc(bs: ^BufString($N)) -> string {
	return string(bs.buf[:bs.len])
}

bufstring_update_from_bytes :: proc(bs: ^BufString($N), bytes_read: i32) {
	bs.len = bytes_read
}

bufstring_update :: proc {
	bufstring_update_from_bytes,
	bufstring_update_from_string,
}
