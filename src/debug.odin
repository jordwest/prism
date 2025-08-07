package main

import "prism"

DebugState :: struct {
	// Should we render the host state instead of client state?
	render_host_state: bool,
}

debug_init :: proc() {
	test_union: TestUnion = VariantA{}
	// do_thing(test_union)

	switch &m in test_union {
	case VariantA:
		do_thing(&m)
	case VariantB:
		do_thing(&m)
	}
}

VariantA :: struct {
	a: int,
}
VariantB :: struct {
	a: int,
	b: int,
}

TestUnion :: union {
	VariantA,
	VariantB,
}

do_thing_a :: proc(va: ^VariantA) {
	trace("%d", va.a)
}
do_thing_b :: proc(vb: ^VariantB) {
	trace("%d", vb.b)
}

do_thing :: proc {
	do_thing_a,
	do_thing_b,
}
