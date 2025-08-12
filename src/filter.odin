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
