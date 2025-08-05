package main

vec2f_from_vec2i :: #force_inline proc(v: [2]i32) -> [2]f32 {
	return {f32(v.x), f32(v.y)}
}
vec2f_from_i32 :: #force_inline proc(v: i32) -> [2]f32 {
	return {f32(v), f32(v)}
}

vec2f :: proc {
	vec2f_from_vec2i,
	vec2f_from_i32,
}
