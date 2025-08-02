package main

import fmt "core:fmt"

LogLevel :: enum {
	Trace,
	Info,
	Warn,
	Error,
}

log_level :: LogLevel.Trace

when log_level <= LogLevel.Trace {
	trace :: proc(s: string, args: ..any) {
		result := fmt.tprintf(s, ..args)
		print(result, i32(LogLevel.Trace))
	}
} else {
	trace :: #force_inline proc(_: ..any) {}
}

when log_level <= LogLevel.Info {
	info :: proc(s: string, args: ..any) {
		result := fmt.tprintf(s, ..args)
		print(result, i32(LogLevel.Info))
	}
} else {
	info :: #force_inline proc(_: ..any) {}
}

when log_level <= LogLevel.Warn {
	warn :: proc(s: string, args: ..any) {
		result := fmt.tprintf(s, ..args)
		print(result, i32(LogLevel.Warn))
	}
} else {
	warn :: #force_inline proc(_: ..any) {}
}

when log_level <= LogLevel.Error {
	err :: #force_inline proc(s: string, args: ..any) {
		result := fmt.tprintf(s, ..args)
		print(result, i32(LogLevel.Error))
	}
} else {
	err :: #force_inline proc(_: ..any) {}
}
