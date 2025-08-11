package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "fresnel"

LogLevel :: enum {
	Trace,
	Info,
	Warn,
	Error,
	Off,
}

@(private = "file")
_tracebuffer: [163840]u8

when LOG_LEVEL <= LogLevel.Trace {
	// trace :: proc(s: string, args: ..any, loc: runtime.Source_Code_Location = #caller_location) {
	// 	mem.arena_free_all(&trace_arena)
	// 	context.allocator = trace_arena_alloc
	// 	context.temp_allocator = trace_arena_alloc
	// 	result := fmt.tprintf(s, ..args)
	// 	str := fmt.tprintf("%s\n   at %s:%d", result, loc.file_path, loc.line)
	// 	fresnel.print(str, i32(LogLevel.Trace))
	// }
	trace :: proc(s: string, args: ..any) {
		// result := fmt.bprintf(_tracebuffer[:], s, ..args)
		result := fmt.bprintf(_tracebuffer[:], s)
		fresnel.print(result, i32(LogLevel.Trace))
	}
} else {
	trace :: #force_inline proc(_: ..any) {}
}

when LOG_LEVEL <= LogLevel.Info {
	info :: proc(s: string, args: ..any) {
		result := fmt.bprintf(_tracebuffer[:], s, ..args)
		fresnel.print(result, i32(LogLevel.Info))
	}
} else {
	info :: #force_inline proc(_: ..any) {}
}

when LOG_LEVEL <= LogLevel.Warn {
	warn :: proc(s: string, args: ..any) {
		result := fmt.bprintf(_tracebuffer[:], s, ..args)
		fresnel.print(result, i32(LogLevel.Warn))
	}
} else {
	warn :: #force_inline proc(_: ..any) {}
}

when LOG_LEVEL <= LogLevel.Error {
	err :: #force_inline proc(s: string, args: ..any) {
		result := fmt.bprintf(_tracebuffer[:], s, ..args)
		fresnel.print(result, i32(LogLevel.Error))
	}
} else {
	err :: #force_inline proc(_: ..any) {}
}

when LOG_LEVEL <= LogLevel.Trace {
	line :: proc(loc: runtime.Source_Code_Location = #caller_location) {
		result := fmt.bprintf(_tracebuffer[:], "%s %d", loc.file_path, loc.line)
		fresnel.metric_str("line", result)
	}
} else {
	line :: #force_inline proc(_: ..any) {}
}
