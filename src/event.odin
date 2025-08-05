package main

import "prism"

Event :: union {
	EventPlayerJoined,
	EventEntitySpawned,
	EventEntityMoved,
	EventEntityCommandChanged,
}

event_union_serialize :: proc(s: ^prism.Serializer, obj: ^Event) -> prism.SerializationResult {
	state := prism.serialize_union_create(s, obj)
	prism.serialize_union_nil(0, &state)
	prism.serialize_union_variant(1, EventPlayerJoined, _event_variant_serialize, &state) or_return
	prism.serialize_union_variant(
		2,
		EventEntitySpawned,
		_event_variant_serialize,
		&state,
	) or_return
	prism.serialize_union_variant(3, EventEntityMoved, _event_variant_serialize, &state) or_return
	prism.serialize_union_variant(
		4,
		EventEntityCommandChanged,
		_event_variant_serialize,
		&state,
	) or_return
	return prism.serialize_union_fail_if_not_found(&state)
}

@(private)
_event_variant_serialize :: proc {
	_event_player_joined_serialize,
	_event_entity_spawned_serialize,
	_event_entity_moved_serialize,
	_event_entity_command_changed_serialize,
}

///////////////////// VARIANTS ////////////////////


EventPlayerJoined :: struct {
	player_id:        PlayerId,
	player_entity_id: EntityId,
}

@(private)
_event_player_joined_serialize :: proc(
	s: ^prism.Serializer,
	ev: ^EventPlayerJoined,
) -> prism.SerializationResult {
	prism.serialize(s, (^i32)(&ev.player_id)) or_return
	prism.serialize(s, (^i32)(&ev.player_entity_id)) or_return
	return nil
}

EventEntitySpawned :: struct {
	entity: Entity,
}

@(private)
_event_entity_spawned_serialize :: proc(
	s: ^prism.Serializer,
	ev: ^EventEntitySpawned,
) -> prism.SerializationResult {
	entity_serialize(s, &ev.entity) or_return
	return nil
}

EventEntityMoved :: struct {
	entity_id: EntityId,
	pos:       TileCoord,
}

@(private)
_event_entity_moved_serialize :: proc(
	s: ^prism.Serializer,
	ev: ^EventEntityMoved,
) -> prism.SerializationResult {
	prism.serialize(s, (^i32)(&ev.entity_id)) or_return
	prism.serialize(s, (^[2]i32)(&ev.pos)) or_return
	return nil
}

EventEntityCommandChanged :: struct {
	entity_id: EntityId,
	cmd:       Command,
}

@(private)
_event_entity_command_changed_serialize :: proc(
	s: ^prism.Serializer,
	ev: ^EventEntityCommandChanged,
) -> prism.SerializationResult {
	prism.serialize(s, (^i32)(&ev.entity_id)) or_return
	command_serialize(s, &ev.cmd) or_return
	return nil
}
