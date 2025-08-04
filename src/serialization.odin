package main

import "prism"

serialize_state :: proc(s: ^prism.Serializer, state: ^SharedState) -> prism.SerializationResult {
	prism.serialize(s, &state.t) or_return
	prism.serialize(s, &state.client.my_token) or_return

	return nil
}
