package main

import "base:runtime"
import "core:fmt"
import "fresnel"
import "prism"

test_serialize_tiles :: proc() {
	test_case("serialize")
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
	test_serialize_tiles()
	fresnel.test_report()
}
