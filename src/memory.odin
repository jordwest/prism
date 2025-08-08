package main
import "core:mem"
import "fresnel"

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

// For storing the arena that gets cleared each frame
@(private)
frame_memory: [1049600]u8
@(private)
frame_arena: mem.Arena
frame_arena_alloc: mem.Allocator

// Clay layout arena
clay_memory: [5116736]u8

_memory_init_done: bool

memory_init :: proc() {
	if _memory_init_done do return

	persistent_arena = mem.Arena {
		data = persistent_memory[:],
	}
	frame_arena = mem.Arena {
		data = frame_memory[:],
	}
	persistent_arena_alloc = mem.arena_allocator(&persistent_arena)
	frame_arena_alloc = mem.arena_allocator(&frame_arena)

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
	fresnel.metric_i32("temp mem", i32(frame_arena.offset))
	fresnel.metric_i32("temp mem peak", i32(frame_arena.peak_used))
	fresnel.metric_i32("temp mem count", i32(frame_arena.temp_count))
}
