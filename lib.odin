package main
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:sync"

// ArrayBufferLike

TestStruct :: struct #packed {
	a: u8,
	b: u32,
	c: u8,
}

ByteStruct :: struct #packed {
	a: u8 "custom info",
	b: u8,
	c: u8,
}

TestUnion :: union {
	i32,
	f32,
	ByteStruct,
	TestStruct,
}

heap: [33554432]u8

foreign import wasm "my_namespace"
@(default_calling_convention = "c")
foreign wasm {
	@(link_name = "test")
	test :: proc(test_struct: ^TestStruct) -> u8 ---
	print :: proc(str: cstring) ---
}

foreign import debug "debug"
@(default_calling_convention = "c")
foreign debug {
	log_pointer :: proc(ptr: rawptr, size: i32) ---
	log_u8 :: proc(info: cstring, val: u8) ---
}

printf :: proc(fmtstr: string, args: ..any) {
	result := fmt.tprintf(fmtstr, ..args)
	cstr := strings.unsafe_string_to_cstring(result)
	print(cstr)
}

@(export)
hello :: proc(s: ^TestStruct) -> u8 {
	test(&TestStruct{a = 60, b = 70, c = 80})

	arena := mem.Arena {
		data = heap[:],
	}
	arena_alloc := mem.arena_allocator(&arena)

	tracking: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking, arena_alloc, arena_alloc)
	context.allocator = mem.tracking_allocator(&tracking)

	v := TestStruct {
		a = 10,
		b = 20,
		c = 30,
	}

	x := make([dynamic]TestStruct, 0, 1)
	defer delete(x)

	heap_struct := new(TestStruct)
	heap_struct.a = 55
	defer free(heap_struct)

	append(&x, TestStruct{a = 1, b = 2, c = 3})
	append(&x, heap_struct^)

	// TestUnion: store struct variant
	uuu: TestUnion
	// uuu = ByteStruct {
	// 	a = 1,
	// 	b = 2,
	// 	c = 3,
	// }
	uuu = TestStruct{}
	print("TestUnion (TestStruct variant) memory:")
	log_pointer(&uuu, size_of(TestUnion))

	// x := [?]TestStruct{TestStruct{a = 1, b = 2, c = 3}, TestStruct{a = 5, b = 6, c = 7}}

	xptr := x[:]
	log_pointer(&xptr, size_of(xptr))
	log_u8("xptr[0].a", xptr[0].a)
	log_pointer(&x, size_of(x))
	log_pointer(&heap, size_of(heap))

	print("It works! 😃  Hey")

	log_pointer(&heap, size_of(heap))

	defer {
		if len(tracking.allocation_map) > 0 {
			printf("=== %v allocations not freed: ===\n", len(tracking.allocation_map))
			for _, entry in tracking.allocation_map {
				printf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		if len(tracking.bad_free_array) > 0 {
			printf("=== %v incorrect frees: ===\n", len(tracking.bad_free_array))
			for entry in tracking.bad_free_array {
				printf("- %p @ %v\n", entry.memory, entry.location)
			}
		}
		mem.tracking_allocator_destroy(&tracking)
	}

	return test(&v)
}
