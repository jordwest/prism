package prism

Percent :: distinct i32

pct_mul_i32 :: proc(pct: Percent, val: i32) -> i32 {
	return (val * i32(pct)) / 100
}
