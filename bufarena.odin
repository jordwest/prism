package prism

import "core:mem"

BufArena :: struct($T: int) {
	memory:    [T]u8,
	arena:     mem.Arena,
	allocator: mem.Allocator,
}

buf_arena_init :: proc(arena: ^BufArena($T)) {
	arena.arena = mem.Arena {
		data = arena.memory[:],
	}
	arena.allocator = mem.arena_allocator(&arena.arena)
}

buf_arena_free :: proc(arena: ^BufArena($T)) {
	mem.arena_free_all(&arena.arena)
}
