package prism

// SplitMix64 inspired by:
// https://www.youtube.com/watch?v=e4b--cyXEsM
rand_splitmix :: proc(seed: u64, gamma: u64, i: u64) -> u64 {
	z: u64 = seed + 0x9e3779b97f4a7c15 + i * gamma
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
rand_splitmix_add_int :: proc(state: ^SplitMixState, val: int) {
	state.z = rand_splitmix(state.seed, state.gamma, state.z + u64(val))
}
rand_splitmix_add_i32 :: proc(state: ^SplitMixState, val: i32) {
	state.z = rand_splitmix(state.seed, state.gamma, state.z + u64(val))
}
rand_splitmix_add_f32 :: proc(state: ^SplitMixState, val: f32) {
	state.z = rand_splitmix(state.seed, state.gamma, state.z + u64(val * (1 << 16)))
}
rand_splitmix_next :: proc(state: ^SplitMixState) {
	rand_splitmix_add_u64(state, 0x876237f67c)
}

rand_splitmix_get_i32_range :: proc(
	state: ^SplitMixState,
	min: i32,
	max: i32,
	advance := true,
) -> i32 {
	if advance do defer rand_splitmix_next(state)
	return min + i32(state.z % u64(max - min))
}

rand_splitmix_get_dice_roll :: proc(state: ^SplitMixState, sides: i32, die: i32 = 1) -> i32 {
	total: i32 = 0
	for i: i32 = 0; i < die; i += 1 {
		total += rand_splitmix_get_i32_range(state, 1, sides + 1)
	}
	return total
}

rand_splitmix_get_tilecoord_in_aabb :: proc(state: ^SplitMixState, aabb: Aabb(i32)) -> TileCoord {
	x := rand_splitmix_get_i32_range(state, aabb.x1, aabb.x2)
	y := rand_splitmix_get_i32_range(state, aabb.y1, aabb.y2)

	return TileCoord({x, y})
}

rand_splitmix_get_u64 :: proc(state: ^SplitMixState, advance := true) -> u64 {
	if advance do defer rand_splitmix_next(state)
	return state.z
}

rand_splitmix_get_u64_max :: proc(state: ^SplitMixState, max: u64, advance := true) -> u64 {
	if advance do defer rand_splitmix_next(state)
	return state.z % max
}

// Returns true in x in 1000 cases. eg if x=100, that's a 10% chance
// Set x=500 for a coin flip
rand_splitmix_get_bool :: proc(state: ^SplitMixState, x: u64 = 500, advance := true) -> bool {
	if advance do defer rand_splitmix_next(state)
	return state.z % 1000 < x
}

rand_splitmix_get_f64 :: proc(state: ^SplitMixState, advance := true) -> f64 {
	if advance do defer rand_splitmix_next(state)
	return f64(state.z) / f64(1 << 64)
}

rand_splitmix_add :: proc {
	rand_splitmix_add_u64,
	rand_splitmix_add_i32,
	rand_splitmix_add_int,
	rand_splitmix_add_f32,
}
