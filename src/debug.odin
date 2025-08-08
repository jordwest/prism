package main

import "fresnel"
import "prism"

DebugState :: struct {
	// Should we render the host state instead of client state?
	render_host_state: bool,
}

debug_init :: proc() {
	fresnel.draw_rect(1, 2, 3, 4)
}
