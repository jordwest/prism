package main

import "prism"

DebugState :: struct {
	// Should we render the host state instead of client state?
	render_host_state: bool,
}

debug_init :: proc() {
	heads := 0
	seed: u64 = 0xdeadbeef
	gamma: u64 = 0x09828988
	rand1 := prism.rand_splitmix_create(seed, gamma)
	prism.rand_splitmix_add_i32(&rand1, 10)
	prism.rand_splitmix_add_i32(&rand1, 20)

	rand2 := prism.rand_splitmix_create(seed, gamma)
	prism.rand_splitmix_add_i32(&rand1, 20)
	prism.rand_splitmix_add_i32(&rand1, 10)

	trace(
		"rand1 = %.4f, rand2 = %.4f",
		prism.rand_splitmix_get_f64(&rand1),
		prism.rand_splitmix_get_f64(&rand2),
	)

	rand3 := prism.rand_splitmix_create(seed, gamma)
	iters: u64 = 100000
	for i: u64 = 0; i < iters; i += 1 {
		prism.rand_splitmix_add(&rand3, f32(i))
		// if prism.rand_splitmix_get_f64(&rand3) >= 0.5 do heads += 1
		if prism.rand_splitmix_get_bool(&rand3) do heads += 1
	}
	trace("Heads %d/%d", heads, iters)
}
