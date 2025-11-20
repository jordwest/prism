package prism

import "core:math"
import "core:math/linalg"

LineIter :: struct {
	d:     [2]i32,
	s:     [2]i32,
	i:     [2]i32,
	end:   [2]i32,
	error: i32,
	next:  Maybe([2]i32),
}

// Creates a Bresenham's line algorithm iterator, yielding a value for each pixel
line :: proc(from: [2]i32, to: [2]i32) -> LineIter {
	dx: i32 = math.abs(to.x - from.x)
	dy: i32 = -math.abs(to.y - from.y)
	sx: i32 = from.x < to.x ? 1 : -1
	sy: i32 = from.y < to.y ? 1 : -1

	return LineIter {
		d = {dx, dy},
		s = {sx, sy},
		error = dx + dy,
		i = from,
		end = to,
		next = [2]i32{from.x, from.y},
	}
}

iterate_line :: proc(iter: ^LineIter) -> ([2]i32, i32, bool) {
	for {
		if next, has_next := iter.next.([2]i32); has_next {
			iter.next = nil
			return next, 0, true
		}

		e2 := 2 * iter.error
		if e2 >= iter.d.y {
			if iter.i.x == iter.end.x do break
			iter.error += iter.d.y
			iter.i.x += iter.s.x
		}
		if e2 <= iter.d.x {
			if iter.i.y == iter.end.y do break
			iter.error += iter.d.x
			iter.i.y += iter.s.y
		}

		iter.next = iter.i
	}
	return {}, 0, false
}
