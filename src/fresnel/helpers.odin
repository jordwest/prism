package fresnel

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:strings"

line :: proc(loc: runtime.Source_Code_Location = #caller_location) {
	str := fmt.tprintf("%s %d", loc.file_path, loc.line)
	metric_str("line", str)
}

@(private = "file")
_draw_text_buffer: [16384]u8

draw_text_fmt :: proc(x: f32, y: f32, size: i32 = 16, fmtstr: string, args: ..any) {
	result := fmt.bprintf(_draw_text_buffer[:], fmtstr, ..args)
	draw_text(x, y, size, result)
}
