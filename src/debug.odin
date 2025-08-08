package main

import "fresnel"
import "prism"

DebugState :: struct {
	// Should we render the host state instead of client state?
	render_debug_overlays: bool,
}

debug_init :: proc() {
	fresnel.draw_rect(1, 2, 3, 4)
	state.debug.render_debug_overlays = DEBUG_OVERLAYS_ENABLED
}
