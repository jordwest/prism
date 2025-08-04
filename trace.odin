package main

import "base:runtime"
import "core:fmt"
import "fresnel"

LogLevel :: enum {
	Trace,
	Info,
	Warn,
	Error,
	Off,
}

when LOG_LEVEL <= LogLevel.Trace {
	trace :: proc(s: string, args: ..any) {
		result := fmt.tprintf(s, ..args)
		fresnel.print(result, i32(LogLevel.Trace))
	}
} else {
	trace :: #force_inline proc(_: ..any) {}
}

when LOG_LEVEL <= LogLevel.Info {
	info :: proc(s: string, args: ..any) {
		result := fmt.tprintf(s, ..args)
		fresnel.print(result, i32(LogLevel.Info))
	}
} else {
	info :: #force_inline proc(_: ..any) {}
}

when LOG_LEVEL <= LogLevel.Warn {
	warn :: proc(s: string, args: ..any) {
		result := fmt.tprintf(s, ..args)
		fresnel.print(result, i32(LogLevel.Warn))
	}
} else {
	warn :: #force_inline proc(_: ..any) {}
}

when LOG_LEVEL <= LogLevel.Error {
	err :: #force_inline proc(s: string, args: ..any) {
		result := fmt.tprintf(s, ..args)
		fresnel.print(result, i32(LogLevel.Error))
	}
} else {
	err :: #force_inline proc(_: ..any) {}
}

when LOG_LEVEL <= LogLevel.Trace {
	line :: proc(loc: runtime.Source_Code_Location = #caller_location) {
		str := fmt.tprintf("%s %d", loc.file_path, loc.line)
		fresnel.metric_str("line", str)
	}
} else {
	line :: #force_inline proc(_: ..any) {}
}
