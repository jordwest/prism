package main

entity_is_obstacle :: proc(entity: ^Entity) -> bool {
	return .IsObstacle in entity.meta.flags
}

filter_is_enemy :: proc(entity: ^Entity) -> bool {
	return entity.meta.team == .Darkness
}

filter_is_player_team :: proc(entity: ^Entity) -> bool {
	return entity.meta.team == .Players
}

filter :: proc(filter_info: EntityFilter, entity: ^Entity) -> bool {
	switch filter_info.type {
	case .ByEntityType:
		return entity.meta_id == filter_info.entity_type
	}

	return false
}

EntityFilter :: struct {
	type:        EntityFilterType,
	entity_type: EntityMetaId,
}

EntityFilterType :: enum {
	ByEntityType,
}
