package main
import "base:runtime"
import "core:mem"
import "fresnel"
import "prism"

// For data that persists for the life of the app
@(private = "file")
persistent_memory: [1049600]u8
@(private = "file")
persistent_arena: mem.Arena
persistent_arena_alloc: mem.Allocator

// For data that persists for the life of the app
@(private = "file")
host_memory: [5242880]u8
@(private = "file")
host_arena: mem.Arena
host_arena_alloc: mem.Allocator

pad1: [104960]u8


pad2: [104960]u8

_serialization_buffer: [16384]u8
_tmp_16k: [16384]u8

// Clay layout arena
clay_memory: [5116736]u8

_memory_init_done: bool

memory_init :: proc() {
	if _memory_init_done do return

	pad1[0] = 1
	pad2[0] = 1

	persistent_arena = mem.Arena {
		data = persistent_memory[:],
	}
	persistent_arena_alloc = mem.arena_allocator(&persistent_arena)

	_memory_init_done = true
}

memory_init_host :: proc() {
	host_arena = mem.Arena {
		data = host_memory[:],
	}
	host_arena_alloc = mem.arena_allocator(&host_arena)
}

memory_log_metrics :: proc() {
	if state.host.is_host {
		fresnel.metric_i32("host mem", i32(host_arena.offset))
		fresnel.metric_i32("host mem peak", i32(host_arena.peak_used))
	}
	fresnel.metric_i32("persistent mem", i32(persistent_arena.offset))
	fresnel.metric_i32("persistent mem peak", i32(persistent_arena.peak_used))
}
