package prism

import "core:math"

// Quantize a value into a range given a number of steps
quantize :: proc(val: f32, steps: f32, min: f32 = 0, max: f32 = 1) -> f32 {
	normalized := math.unlerp(min, max, val)
	step := math.round(normalized * steps)
	return min + (step / steps)
}
