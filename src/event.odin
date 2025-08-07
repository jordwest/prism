package main

import "prism"

Event :: union {
	EventPlayerJoined,
	EventEntitySpawned,
	EventEntityMoved,
	EventEntityCommandChanged,
}

S :: ^prism.Serializer
SResult :: prism.SerializationResult

event_union_serialize :: proc(s: ^prism.Serializer, obj: ^Event) -> prism.SerializationResult {
	state := prism.serialize_union_create(s, obj)
	prism.serialize_union_nil(0, &state)
	prism.serialize_union_variant(
		1,
		EventPlayerJoined,
		proc(s: S, ev: ^EventPlayerJoined) -> SResult {
			prism.serialize(s, (^i32)(&ev.player_id)) or_return
			prism.serialize(s, (^i32)(&ev.player_entity_id)) or_return
			return nil
		},
		&state,
	) or_return

	prism.serialize_union_variant(
		2,
		EventEntitySpawned,
		proc(s: S, ev: ^EventEntitySpawned) -> SResult {
			entity_serialize(s, &ev.entity) or_return
			return nil
		},
		&state,
	) or_return

	prism.serialize_union_variant(
		3,
		EventEntityMoved,
		proc(s: S, ev: ^EventEntityMoved) -> SResult {
			prism.serialize(s, (^i32)(&ev.entity_id)) or_return
			prism.serialize(s, (^[2]i32)(&ev.pos)) or_return
			return nil
		},
		&state,
	) or_return

	prism.serialize_union_variant(
		4,
		EventEntityCommandChanged,
		proc(s: S, ev: ^EventEntityCommandChanged) -> SResult {
			prism.serialize(s, (^i32)(&ev.entity_id)) or_return
			prism.serialize(s, (^i32)(&ev.seq)) or_return
			command_serialize(s, &ev.cmd) or_return
			return nil
		},
		&state,
	) or_return
	return prism.serialize_union_fail_if_not_found(&state)
}

///////////////////// VARIANTS ////////////////////


EventPlayerJoined :: struct {
	player_id:        PlayerId,
	player_entity_id: EntityId,
}

// event_handle_player_joined

EventEntitySpawned :: struct {
	entity: Entity,
}

EventEntityMoved :: struct {
	entity_id: EntityId,
	pos:       TileCoord,
}

EventEntityCommandChanged :: struct {
	entity_id: EntityId,
	seq:       i32,
	cmd:       Command,
}
