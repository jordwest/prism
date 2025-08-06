package prism

Aabb :: struct($T: typeid) {
	x1: T,
	y1: T,
	x2: T,
	y2: T,
}

aabb_overlaps :: proc(a: Aabb($T), b: Aabb(T)) -> bool {
	overlaps_x := (a.x1 <= b.x1 && a.x2 >= b.x1) || b.x1 <= a.x1 && b.x2 >= a.x1
	overlaps_y := (a.y1 <= b.y1 && a.y2 >= b.y1) || b.y1 <= a.y1 && b.y2 >= a.y1
	return overlaps_x && overlaps_y
}

// Inner aabb does not cross outside the container aabb
aabb_fully_contains :: proc(container: Aabb($T), inner: Aabb(T)) -> bool {
	return(
		container.x1 <= inner.x1 &&
		container.x2 >= inner.x2 &&
		container.y1 <= inner.y1 &&
		container.y2 >= inner.y2 \
	)
}

aabb_contains_point :: proc(container: Aabb($T), point: [2]T) -> bool {
	return(
		point.x >= container.x1 &&
		point.x <= container.x2 &&
		point.y >= container.y1 &&
		point.y <= container.y2 \
	)
}

aabb_size :: proc(aabb: Aabb($T)) -> [2]T {
	return {aabb.x2 - aabb.x1, aabb.y2 - aabb.y1}
}

aabb_grow :: proc(aabb: Aabb($T), size: [2]T) -> Aabb(T) {
	return Aabb(T) {
		x1 = aabb.x1 - size.x,
		y1 = aabb.y1 - size.y,
		x2 = aabb.x2 + size.x,
		y2 = aabb.y2 + size.y,
	}
}
