package prism

BufString :: struct($N: int) {
	buf: [N]u8,
	str: string,
}

bufstring_from_string :: proc($Length: int, str: string) -> BufString(Length) {
	return BufString(Length){str = str}
}

bufstring_update_from_string :: proc(bs: ^BufString($N), str: string) {
	bs.str = str
}

bufstring_update_from_bytes :: proc(bs: ^BufString($N), bytes_read: int) {
	bs.str = string(bs.buf[:bytes_read])
}

bufstring_update :: proc {
	bufstring_update_from_bytes,
	bufstring_update_from_string,
}
