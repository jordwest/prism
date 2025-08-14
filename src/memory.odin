package main
import "base:runtime"
import "core:fmt"
import "core:mem"
import "fresnel"
import "prism"

Arena :: struct($T: int) {
	memory:    [T]u8,
	arena:     mem.Arena,
	allocator: mem.Allocator,
}

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

arena_ui_frame: Arena(5242880)

_serialization_buffer: [16384]u8
_tmp_16k: [16384]u8

pad_before_state: prism.MemPadding

state: AppState

arena_containers: Arena(102400) // containers.odin

pad_after_state: prism.MemPadding

// Clay layout arena
clay_memory: [5116736]u8
clay_memory_tooltip: [2558368]u8

pad_after_clay: prism.MemPadding

_memory_init_done: bool

@(private = "file")
_init_arena :: proc(arena: ^Arena($T)) {
	arena.arena = mem.Arena {
		data = arena.memory[:],
	}
	arena.allocator = mem.arena_allocator(&arena.arena)
}

arena_free :: proc(arena: ^Arena($T)) {
	mem.arena_free_all(&arena.arena)
}

memory_validate :: proc(loc := #caller_location) {
	if uintptr(fmt._user_formatters) != 0 {
		v := uintptr(fmt._user_formatters)
		fmt._user_formatters = nil
		trace("_user_formatters was %d at %s:%d", v, loc.file_path, loc.line)
		unreachable()
	}

	when MEMORY_VALIDATE_PADDING {
		prism.mempad_validate(&pad_before_state)
		prism.mempad_validate(&pad_after_state)
		prism.mempad_validate(&pad_after_clay)
	}
}

memory_init :: proc() {
	if _memory_init_done do return

	persistent_arena = mem.Arena {
		data = persistent_memory[:],
	}
	persistent_arena_alloc = mem.arena_allocator(&persistent_arena)

	_init_arena(&arena_ui_frame)
	_init_arena(&arena_containers)

	fresnel.log_i32("persistent mem loc", i32(uintptr(&persistent_memory)))
	fresnel.log_i32("state_mem_start", i32(uintptr(&state)))
	fresnel.log_i32("state_mem_end", i32(uintptr(&state)) + size_of(state))
	fresnel.log_i32("clay_mem_start", i32(uintptr(&clay_memory)))
	fresnel.log_i32("clay_mem_end", i32(uintptr(&clay_memory)) + len(clay_memory))

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
