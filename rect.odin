package prism

Rect :: struct($T: typeid) {
	x1: T,
	y1: T,
	x2: T,
	y2: T,
}

RectIterator :: struct($T: typeid) {
	rect:  Rect(T),
	index: int,
	x:     T,
	y:     T,
}

rect :: proc(pos: [2]$T, size: [2]T) -> Rect(T) {
	return Rect(T){x1 = pos.x, y1 = pos.y, x2 = pos.x + size.x, y2 = pos.y + size.y}
}

rect_iterator :: proc(rect: Rect($T)) -> RectIterator(T) {
	return RectIterator(T){rect = rect, x = rect.x1, y = rect.y1}
}

rect_iterate :: proc(iter: ^RectIterator($T)) -> (val: [2]T, idx: int, ok: bool) {
	// Finished iterating
	if iter.y >= iter.rect.y2 do return 0, 0, false

	x := iter.x
	y := iter.y
	index := iter.index

	if iter.x < iter.rect.x2 - 1 {
		iter.x += 1
	} else {
		// Finished column, next row
		iter.x = iter.rect.x1
		iter.y += 1
	}
	iter.index += 1

	return {x, y}, index, true
}

rect_overlaps :: proc(a: Rect($T), b: Rect(T)) -> bool {
	overlaps_x := (a.x1 <= b.x1 && a.x2 >= b.x1) || b.x1 <= a.x1 && b.x2 >= a.x1
	overlaps_y := (a.y1 <= b.y1 && a.y2 >= b.y1) || b.y1 <= a.y1 && b.y2 >= a.y1
	return overlaps_x && overlaps_y
}

rect_is_edge :: proc(a: Rect($T), coord: [2]T) -> bool {
	return coord.x == a.x1 || coord.x == a.x2 - 1 || coord.y == a.y1 || coord.y == a.y2 - 1
}

// Inner rect does not cross outside the container rect
rect_fully_contains :: proc(container: Rect($T), inner: Rect(T)) -> bool {
	return(
		container.x1 <= inner.x1 &&
		container.x2 >= inner.x2 &&
		container.y1 <= inner.y1 &&
		container.y2 >= inner.y2 \
	)
}

rect_contains_point :: proc(container: Rect($T), point: [2]T) -> bool {
	return(
		point.x >= container.x1 &&
		point.x <= container.x2 &&
		point.y >= container.y1 &&
		point.y <= container.y2 \
	)
}

rect_pos :: proc(rect: Rect($T)) -> [2]T {
	return {rect.x1, rect.y1}
}

rect_rand_tile_coord :: proc(rect: Rect(i32), rng: ^SplitMixState) -> TileCoord {
	return {
		rand_splitmix_get_i32_range(rng, rect.x1, rect.x2),
		rand_splitmix_get_i32_range(rng, rect.y1, rect.y2),
	}
}

rect_size :: proc(rect: Rect($T)) -> [2]T {
	return {rect.x2 - rect.x1, rect.y2 - rect.y1}
}

rect_grow :: proc(rect: Rect($T), size: [2]T) -> Rect(T) {
	return Rect(T) {
		x1 = rect.x1 - size.x,
		y1 = rect.y1 - size.y,
		x2 = rect.x2 + size.x,
		y2 = rect.y2 + size.y,
	}
}
