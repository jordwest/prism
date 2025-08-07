package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "prism"

InnerError :: union {
	EntityNotFound,
	EntityExists,
	InvariantError,
	SerializationError,
	DeserializationError,
	mem.Allocator_Error,
}

Error :: union {
	ErrorContainer,
}

ErrorContainer :: struct {
	source: runtime.Source_Code_Location,
	error:  InnerError,
}

EntityNotFound :: struct {
	entity_id: EntityId,
}

EntityExists :: struct {
	existing: Entity,
	new:      Entity,
}

SerializationError :: struct {
	result: prism.SerializationResult,
	data:   string,
	offset: i32,
}

DeserializationError :: struct {
	result: prism.SerializationResult,
	data:   []u8,
	offset: i32,
}

InvariantError :: struct {}

error :: proc(e: InnerError, loc: runtime.Source_Code_Location = #caller_location) -> Error {
	return ErrorContainer{source = loc, error = e}
}

error_log :: proc(e: Error, loc: runtime.Source_Code_Location = #caller_location) -> Error {
	if err_container, ok := e.(ErrorContainer); ok {
		source := err_container.source
		err(
			"Error reported at\n%s:%d:%s\n%s:%d:%s\n\n%w",
			loc.file_path,
			loc.line,
			loc.procedure,
			source.file_path,
			source.line,
			source.procedure,
			err_container.error,
		)
	}
	return e
}
