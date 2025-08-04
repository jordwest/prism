package main
import "core:mem"

// For data that persists for the life of the app
@(private) persistent_memory: [1049600]u8
@(private) persistent_arena: mem.Arena
persistent_arena_alloc: mem.Allocator

// For data that persists for the life of the app
@(private) host_memory: [1049600]u8
@(private) host_arena: mem.Arena
host_arena_alloc: mem.Allocator

// For storing the arena that gets cleared each frame
@(private) frame_memory: [1049600]u8
@(private) frame_arena: mem.Arena
frame_arena_alloc: mem.Allocator

// Clay layout arena
clay_memory: [5116736]u8

memory_init :: proc() {
    persistent_arena = mem.Arena {
		data = persistent_memory[:],
	}
	frame_arena = mem.Arena {
		data = frame_memory[:],
	}
	persistent_arena_alloc = mem.arena_allocator(&persistent_arena)
	frame_arena_alloc = mem.arena_allocator(&frame_arena)
}

memory_init_host :: proc() {
    host_arena = mem.Arena {
		data = host_memory[:],
	}
	host_arena_alloc = mem.arena_allocator(&host_arena)
}
