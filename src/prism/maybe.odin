package prism

maybe_any :: proc($T: typeid, maybes: []Maybe(T)) -> Maybe(T) {
	for maybe in maybes {
		val, ok := maybe.?
		if ok do return val
	}

	return nil
}
