package main

import "prism"

Event :: union {
	EventEntitySpawned,
	EventEntityMoved,
}

event_union_serialize :: proc(s: ^prism.Serializer, obj: ^Event) -> prism.SerializationResult {
	state := prism.serialize_union_create(s, obj)
	prism.serialize_union_nil(0, &state)
	prism.serialize_union_variant(1, EventEntitySpawned, event_variant_serialize, &state) or_return
	prism.serialize_union_variant(2, EventEntityMoved, event_variant_serialize, &state) or_return
	return prism.serialize_union_fail_if_not_found(&state)
}

event_variant_serialize :: proc {
	event_entity_spawned_serialize,
	event_entity_moved_serialize,
}

///////////////////// VARIANTS ////////////////////

EventEntitySpawned :: struct {
	entity: Entity,
}

@(private)
event_entity_spawned_serialize :: proc(
	s: ^prism.Serializer,
	msg: ^EventEntitySpawned,
) -> prism.SerializationResult {
	entity_serialize(s, &msg.entity) or_return
	return nil
}

EventEntityMoved :: struct {
	entity_id: EntityId,
	pos:       TileCoord,
}

@(private)
event_entity_moved_serialize :: proc(
	s: ^prism.Serializer,
	msg: ^EventEntityMoved,
) -> prism.SerializationResult {
	prism.serialize(s, (^i32)(&msg.entity_id)) or_return
	prism.serialize(s, (^[2]i32)(&msg.pos)) or_return
	return nil
}
