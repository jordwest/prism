package prism

// SplitMix64 inspired by:
// https://www.youtube.com/watch?v=e4b--cyXEsM
rand_splitmix :: proc(seed: u64, gamma: u64, i: u64) -> u64 {
	z: u64 = seed + i * gamma
	z = (z ~ (z >> 30)) * 0xbf58476d1ce4e5b9
	z = (z ~ (z >> 27)) * 0x94d049bb133111eb
	return z ~ (z >> 31)
}

rand_splitmix_f64 :: proc(seed: u64, gamma: u64, i: u64) -> f64 {
	return f64(rand_splitmix(seed, gamma, i)) / f64(1 << 64)
}

SplitMixState :: struct {
	seed:  u64,
	gamma: u64,
	z:     u64,
}

rand_splitmix_create :: proc(seed: u64, gamma: u64) -> SplitMixState {
	return SplitMixState{seed = seed, gamma = gamma, z = rand_splitmix(seed, gamma, 1)}
}
rand_splitmix_add_u64 :: proc(state: ^SplitMixState, val: u64) {
	state.z = rand_splitmix(state.seed, state.gamma, state.z + val)
}
rand_splitmix_add_i32 :: proc(state: ^SplitMixState, val: i32) {
	state.z = rand_splitmix(state.seed, state.gamma, state.z + u64(val))
}
rand_splitmix_add_f32 :: proc(state: ^SplitMixState, val: f32) {
	state.z = rand_splitmix(state.seed, state.gamma, state.z + u64(val * (1 >> 32)))
}

rand_splitmix_get_u64_max :: proc(state: ^SplitMixState, max: u64) -> u64 {
	return state.z % max
}

// Returns true in x in 1000 cases. eg if x=100, that's a 10% chance
// Set x=500 for a coin flip
rand_splitmix_get_bool :: proc(state: ^SplitMixState, x: u64 = 500) -> bool {
	return state.z % 1000 < x
}

rand_splitmix_get_f64 :: proc(state: ^SplitMixState) -> f64 {
	return f64(state.z) / f64(1 << 64)
}

rand_splitmix_add :: proc {
	rand_splitmix_add_u64,
	rand_splitmix_add_i32,
	rand_splitmix_add_f32,
}
