package prism

// Simple spring-mass-damper for smooth and responsive animations
Spring :: struct($N: int) {
	// Spring constant
	k:      f32,

	// Mass
	m:      f32,

	// Damping constant
	c:      f32,

	// Position of one end of the spring
	pos:    [N]f32,

	// Position of other end of the spring (pos will move toward this)
	target: [N]f32,

	// Velocity
	vel:    [N]f32,
}

spring_create :: proc(
	$N: int,
	initial_position: [N]f32,
	k: f32 = 100,
	m: f32 = 1,
	c: f32 = 20,
) -> Spring(N) {
	return Spring(N){k = k, m = m, c = c, pos = initial_position, target = initial_position}
}

spring_tick :: proc(spring: ^Spring($N), dt: f32) {
	x := spring.pos - spring.target
	f := -spring.k * x - spring.c * spring.vel

	spring.vel += (f / spring.m) * dt
	spring.pos += spring.vel * dt
}
