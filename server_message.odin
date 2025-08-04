package main
import "core:reflect"
import "fresnel"
import "prism"

ServerMessage :: union {
	ServerMessageWelcome,
}

server_message_union_serialize :: proc(s: ^prism.Serializer, obj: ^ServerMessage) {
	state := prism.serialize_union_create(s, obj)
	prism.serialize_union_nil(0, &state)
	prism.serialize_union_variant(1, ServerMessageWelcome, prism.serialize_empty, &state)
}

@(private)
server_message_serialize_variant :: proc {
	welcome_serialize,
}

/************
 * Variants
 ***********/

ServerMessageWelcome :: struct { }

@(private)
welcome_serialize :: proc(
	s: ^prism.Serializer,
	msg: ^ServerMessageWelcome,
) -> prism.SerializationResult {
	return nil
}
