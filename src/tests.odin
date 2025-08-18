package main

import "base:runtime"
import "core:fmt"
import "core:mem"
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

	assert_eq(dmap.state, prism.DjikstraMapState.Complete)

	tile, ok := prism.djikstra_tile(&dmap, {7, 5}).?
	assert_eq(tile^, prism.DjikstraTile{cost = 2, visited = true})
	assert_eq(prism.djikstra_tile(&dmap, {3997, 5}), nil)

	test_complete()
}

test_generational_array :: proc() {
	test_case("generate map")

	arr := prism.Pool(u8, 4){}
	prism.pool_init(&arr)

	id1_1, _, _ := prism.pool_add(&arr, 52)
	assert_eq(id1_1.id, 1)
	assert_eq(id1_1.gen, 1)

	id2_1, _, _ := prism.pool_add(&arr, 48)
	assert_eq(id2_1.id, 2)
	assert_eq(id2_1.gen, 1)

	id3_1, _, _ := prism.pool_add(&arr, 23)
	assert_eq(id3_1.id, 3)
	assert_eq(id3_1.gen, 1)

	deleted := prism.pool_delete(&arr, id2_1)
	assert_eq(deleted, 48)

	id2_2, _, _ := prism.pool_add(&arr, 23)
	assert_eq(id2_2.id, 2)
	assert_eq(id2_2.gen, 2)

	deleted2 := prism.pool_delete(&arr, id2_2)
	assert_eq(deleted2, 23)

	id2_3, _, _ := prism.pool_add(&arr, 18)
	assert_eq(id2_3.id, 2)
	assert_eq(id2_3.gen, 3)

	id4_1, _, _ := prism.pool_add(&arr, 100)
	assert_eq(id4_1.id, 4)
	assert_eq(id4_1.gen, 1)

	deleted3 := prism.pool_delete(&arr, id1_1)
	deleted4 := prism.pool_delete(&arr, id2_1)
	deleted5 := prism.pool_delete(&arr, id3_1)
	assert_eq(deleted3, 52)
	assert_eq(deleted4, nil)
	assert_eq(deleted5, 23)

	id1_2, _, _ := prism.pool_add(&arr, 100)
	assert_eq(id1_2.id, 1)
	assert_eq(id1_2.gen, 2)

	id3_2, _, _ := prism.pool_add(&arr, 100)
	assert_eq(id3_2.id, 3)
	assert_eq(id3_2.gen, 2)

	// Already at capacity
	id, _, ok := prism.pool_add(&arr, 100)
	assert_eq(ok, false)
	assert_eq(id.id, 0)
	assert_eq(id.gen, 0)

	assert_eq(arr.generations[0], 0)
	assert_eq(arr.generations[1], 2)
	assert_eq(arr.generations[2], 3)
	assert_eq(arr.generations[3], 2)
	assert_eq(arr.generations[4], 1)

	test_complete()
}

//////////// UTILS \\\\\\\\\\\\\

test_complete :: fresnel.test_complete

assert_eq :: proc(actual: $T, expected: T, loc: runtime.Source_Code_Location = #caller_location) {
	if actual == expected {
		fresnel.test_assert("", true)
		return
	}

	name := fmt.bprintf(
		_tmp_16k[:],
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
	name := fmt.bprintf(_tmp_16k[:], "%s %s:%s:%d", msg, loc.file_path, loc.procedure, loc.line)
	fresnel.test_assert(name, pass)
}

test_case :: proc(name: string, loc := #caller_location) {
	test_name := fmt.bprintf(_tmp_16k[:], "%s:%s", loc.procedure, name)
	fresnel.test_case(test_name)
}

tests_run_all :: proc() {
	test_generate_djikstra_map()
	test_generational_array()
	fresnel.test_report()
}
