package prism

import "core:math"

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

spring_reset_to :: proc(spring: ^Spring($N), pos: [N]f32) {
	spring.pos = pos
	spring.target = pos
}

import "../fresnel"
import "core:fmt"

spring_tick :: proc(spring: ^Spring($N), _dt: f32, reset := false) {
	dt := f32(0.04)
	if spring.k == 0 || reset {
		// Spring disabled
		spring.pos = spring.target
		return
	}

	x := spring.pos - spring.target
	f := -spring.k * x - spring.c * spring.vel

	spring.vel += (f / spring.m) * dt
	if math.abs(spring.vel.x) > f32(1000) || math.abs(spring.vel.y) > f32(1000) {
		s := fmt.tprintf("Spring velocity broke %v on dt=%.4f", spring, dt)
		fresnel.print(s)
		spring.vel = {0, 0}
		spring.pos = spring.target
	}
	spring.pos += spring.vel * dt
}
