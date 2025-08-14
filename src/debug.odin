package main

import "core:container/queue"
import "core:math"
import "fresnel"
import "prism"

DebugState :: struct {
	// Should we render the host state instead of client state?
	render_debug_overlays: bool,
	view:                  DebugView,
	frame_time_queue:      queue.Queue(f32),
	turn_stepping:         DebugTurnStepState,
}

DebugTurnStepState :: enum {
	Off,
	Paused,
	Step,
}

DebugView :: enum {
	None,
	CurrentPlayerDjikstra,
	AllPlayersDjikstra,
}

@(private = "file")
_frame_time_queue: [60]f32

debug_init :: proc() {
	fresnel.draw_rect(1, 2, 3, 4)
	queue.init_with_contents(&state.debug.frame_time_queue, _frame_time_queue[:])
	state.debug.render_debug_overlays = DEBUG_OVERLAYS_ENABLED
	state.debug.turn_stepping = DEBUG_TURN_STEPPING ? .Paused : .Off
}

debug_tick :: proc(dt: f32) {
	queue.pop_front(&state.debug.frame_time_queue)
	queue.push_back(&state.debug.frame_time_queue, dt)
}

debug_next_view :: proc() {
	state.debug.render_debug_overlays = true
	state.debug.view = DebugView((int(state.debug.view) + 1) % len(DebugView))
}

debug_get_fps :: proc() -> (avg: f32, max: f32, min: f32) {
	time: f32 = 0

	min_t: f32 = 999999
	max_t: f32 = 0

	for t in _frame_time_queue {
		time += t
		min_t = math.min(min_t, t)
		max_t = math.max(max_t, t)
	}

	return 1 / (time / len(_frame_time_queue)), (1 / min_t), (1 / max_t)
}
