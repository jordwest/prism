package main

import "prism"

///////////////////// VARIANTS ////////////////////

EventEntitySpawned :: struct {
	entity: Entity,
}

EventEntityMoved :: struct {
	entity_id: EntityId,
	pos:       TileCoord,
}

///////////////////// UNION ////////////////////

Event :: union {
	EventEntitySpawned,
	EventEntityMoved,
}

///////////////////// HANDLERS ////////////////////

event_entity_spawned_handle :: proc(
	s: ^GameState,
	evt: EventEntitySpawned,
	authority: bool,
) -> Error {
	existing_entity, exists_already := &s.entities[evt.entity.id]
	if exists_already do return error(EntityExists{existing = existing_entity^, new = evt.entity})

	s.entities[evt.entity.id] = evt.entity

	return nil
}

event_entity_moved_handle :: proc(s: ^GameState, evt: EventEntityMoved, authority: bool) -> Error {
	entity, ok := &s.entities[evt.entity_id]
	if !ok do return error(EntityNotFound{entity_id = evt.entity_id})

	entity.pos = evt.pos
	return nil
}


event_handle :: proc(s: ^GameState, e: Event, authority: bool) -> Error {
	switch event in e {
	case EventEntitySpawned:
		return event_entity_spawned_handle(s, event, authority)
	case EventEntityMoved:
		return event_entity_moved_handle(s, event, authority)
	}
	return error(InvariantError{})
}
