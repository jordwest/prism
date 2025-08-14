package main

import "prism"

Player :: struct {
	player_id:         PlayerId,
	player_entity_id:  EntityId,
	display_name:      string,

	// Not deterministic
	cursor_tile:       TileCoord,
	cursor_updated_at: f32,
	cursor_spring:     prism.Spring(2),
}

player_id_serialize :: proc(s: ^prism.Serializer, eid: ^PlayerId) -> prism.SerializationResult {
	return prism.serialize_i32(s, (^i32)(eid))
}

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

player_is_alone :: proc() -> bool {
	return len(state.client.game.players) == 1
}

player_from_entity :: proc(entity: ^Entity) -> Maybe(^Player) {
	player_id, is_player := entity.player_id.?
	if !is_player do return nil

	player, ok := &state.client.game.players[player_id]
	if !ok do return nil

	return player
}
