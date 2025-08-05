package main

import "prism"

CommandTypeId :: enum u8 {
	None,
	Move,
	Attack,
}

Command :: struct {
	type:          CommandTypeId,
	pos:           TileCoord,
	target_entity: EntityId,
}

command_serialize :: proc(s: ^prism.Serializer, cmd: ^Command) -> prism.SerializationResult {
	prism.serialize(s, (^u8)(&cmd.type)) or_return
	prism.serialize(s, (^[2]i32)(&cmd.pos)) or_return
	prism.serialize(s, (^i32)(&cmd.target_entity)) or_return
	return nil
}
