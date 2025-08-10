package main

import "prism"

player_entity :: proc() -> Maybe(^Entity) {
	entity, ok := &state.client.game.entities[state.client.controlling_entity_id]
	if ok do return entity
	return nil
}

player_has_ap :: proc() -> bool {
	entity := player_entity().? or_else &Entity{}
	return entity.action_points > 0
}

player_needs_input :: proc() -> bool {
	entity := player_entity().? or_else &Entity{}
	return entity_get_command(entity).type == .None || entity.action_points > 0
}
