package main

import "base:runtime"
import "core:fmt"
import "fresnel"
import "prism"

test_generate_djikstra_map :: proc() {
	test_case("generate map")

	algo := prism.DjikstraAlgo(10, 10){}
	prism.djikstra_init(&algo)

	dmap := prism.DjikstraMap(10, 10){}
	prism.djikstra_map_init(&dmap, &algo)
	prism.djikstra_map_add_origin(&algo, {5, 5})
	prism.djikstra_map_generate(&algo, proc(from: [2]i32, to: [2]i32) -> i32 {
		return 1
	})


	tile, ok := prism.djikstra_tile(&dmap, {7, 5}).?
	assert_eq(tile^, prism.DjikstraTile{cost = 2, visited = true})
	assert_eq(prism.djikstra_tile(&dmap, {3997, 5}), nil)

	test_complete()
}

//////////// UTILS \\\\\\\\\\\\\

test_complete :: fresnel.test_complete

assert_eq :: proc(actual: $T, expected: T, loc: runtime.Source_Code_Location = #caller_location) {
	if actual == expected {
		fresnel.test_assert("", true)
		return
	}

	name := fmt.tprintf(
		"%s:%s:%d\nGot %v, expected %v",
		loc.file_path,
		loc.procedure,
		loc.line,
		actual,
		expected,
	)
	fresnel.test_assert(name, false)
}
assert :: proc(
	pass: bool,
	msg: string = "",
	loc: runtime.Source_Code_Location = #caller_location,
) {
	name := fmt.tprintf("%s %s:%s:%d", msg, loc.file_path, loc.procedure, loc.line)
	fresnel.test_assert(name, pass)
}

test_case :: proc(name: string, loc := #caller_location) {
	test_name := fmt.tprintf("%s:%s", loc.procedure, name)
	fresnel.test_case(test_name)
}

tests_run_all :: proc() {
	test_generate_djikstra_map()
	fresnel.test_report()
}
