package main

import "prism"

serialize_state :: proc(s: ^prism.Serializer, state: ^GameState) -> prism.SerializationResult {
	prism.serialize(s, &state.t) or_return
	prism.serialize(s, &state.test) or_return
	prism.serialize(s, &state.greeting) or_return
	return nil
}
