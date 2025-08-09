package main

import "core:container/queue"
import "fresnel"
import "prism"

DebugState :: struct {
	// Should we render the host state instead of client state?
	render_debug_overlays: bool,
	frame_time_queue:      queue.Queue(f32),
}

@(private = "file")
_frame_time_queue: [10]f32

debug_init :: proc() {
	fresnel.draw_rect(1, 2, 3, 4)
	queue.init_with_contents(&state.debug.frame_time_queue, _frame_time_queue[:])
	state.debug.render_debug_overlays = DEBUG_OVERLAYS_ENABLED
}

debug_tick :: proc(dt: f32) {
	queue.pop_front(&state.debug.frame_time_queue)
	queue.push_back(&state.debug.frame_time_queue, dt)
}

debug_get_fps :: proc() -> f32 {
	time: f32 = 0
	for t in _frame_time_queue {
		time += t
	}

	return 1 / (time / len(_frame_time_queue))
}
