package main

import "prism"

///////////////////// VARIANTS ////////////////////

EventPlayerJoined :: struct {
	player_id:        PlayerId,
	player_entity_id: EntityId,

	// Host only
	_token:           [16]u8,
}

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

///////////////////// UNION ////////////////////

Event :: union {
	EventPlayerJoined,
	EventEntitySpawned,
	EventEntityMoved,
	EventEntityCommandChanged,
}

///////////////////// HANDLERS ////////////////////

event_player_joined_handle :: proc(
	s: ^CommonState,
	evt: EventPlayerJoined,
	authority: bool,
) -> Error {
	s.players[evt.player_id] = Player {
		player_id        = evt.player_id,
		player_entity_id = evt.player_entity_id,
		_token           = evt._token,
		_cursor_spring   = prism.spring_create(2, [2]f32{0, 0}, k = 40, c = 10),
	}

	player_entity, ok := &s.entities[evt.player_entity_id]
	if !ok do return error(EntityNotFound{entity_id = evt.player_entity_id})

	player_entity.player_id = evt.player_id

	return nil
}

event_entity_spawned_handle :: proc(
	s: ^CommonState,
	evt: EventEntitySpawned,
	authority: bool,
) -> Error {
	existing_entity, exists_already := &s.entities[evt.entity.id]
	if exists_already do return error(EntityExists{existing = existing_entity^, new = evt.entity})

	s.entities[evt.entity.id] = evt.entity

	return nil
}

event_entity_moved_handle :: proc(
	s: ^CommonState,
	evt: EventEntityMoved,
	authority: bool,
) -> Error {
	entity, ok := &s.entities[evt.entity_id]
	if !ok do return error(EntityNotFound{entity_id = evt.entity_id})

	entity.pos = evt.pos
	return nil
}

event_entity_command_changed_handle :: proc(
	s: ^CommonState,
	evt: EventEntityCommandChanged,
	authority: bool,
) -> Error {
	entity, ok := &s.entities[evt.entity_id]
	if !ok do return error(EntityNotFound{entity_id = evt.entity_id})

	entity.cmd = evt.cmd

	if !authority {
		// Client only
		if _local_cmd, has_local := entity._local_cmd.?; has_local {
			if evt.seq >= _local_cmd.seq {
				trace("Clearing local cmd %d, %d", evt.seq, _local_cmd.seq)
				// Server is now ahead of our local state so we can safely clear it
				entity._local_cmd = nil
			} else {
				trace("Local cmd is still newer than server")
			}
		}
	}

	if p, is_player := &s.players[entity.player_id.? or_else 0]; is_player {
		// Mark their cursor as stale to hide it immediately
		p.cursor_updated_at = 0
	}
	return nil
}

event_handle :: proc(s: ^CommonState, e: Event, authority: bool) -> Error {
	switch event in e {
	case EventPlayerJoined:
		return event_player_joined_handle(s, event, authority)
	case EventEntitySpawned:
		return event_entity_spawned_handle(s, event, authority)
	case EventEntityMoved:
		return event_entity_moved_handle(s, event, authority)
	case EventEntityCommandChanged:
		return event_entity_command_changed_handle(s, event, authority)
	}
	return error(InvariantError{})
}

///////////////////// SERIALIZATION ////////////////////

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
