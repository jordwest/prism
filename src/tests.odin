package main

import "base:runtime"
import "core:fmt"
import "fresnel"
import "prism"

test_serialize_tiles :: proc() {
	test_case("serialize")

	tiles_se := Tiles{}
	tiles_se.data[3].type = .BrickWall
	tiles_se.data[8].type = .RopeBridge
	tiles_se.data[12].type = .Water
	ser := prism.create_serializer(context.temp_allocator)
	err_ser := tiles_serialize(&ser, &tiles_se)
	assert_eq(err_ser, nil)
	assert_eq(len(ser.stream), 4 + LEVEL_WIDTH * LEVEL_HEIGHT)

	test_complete()

	//------------

	test_case("deserialize")

	tiles_de := Tiles{}
	deser := prism.create_deserializer(ser.stream)
	err_deser := tiles_serialize(&deser, &tiles_se)
	assert_eq(err_deser, nil)
	assert_eq(tiles_de.data[3].type, TileType.BrickWall)
	assert_eq(tiles_de.data[8].type, TileType.RopeBridge)
	assert_eq(tiles_de.data[12].type, TileType.Water)
	assert_eq(deser.offset, 4 + LEVEL_WIDTH * LEVEL_HEIGHT)

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

tests :: proc() {
	test_serialize_tiles()
	fresnel.test_report()
}
