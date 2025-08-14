package main

import "prism"

Event :: union {
	EventEntityDied,
	EventEntityHurt,
	EventEntityMiss,
	EventTurnStarting,
	EventTurnEnding,
	EventGameOver,
}

EventTurnStarting :: struct {}
EventTurnEnding :: struct {}

DamageSource :: enum {
	Enemy,
	Fire,
}

EventGameOver :: struct {}

EventEntityMiss :: struct {
	target_id:   EntityId,
	attacker_id: EntityId,
}

EventEntityHurt :: struct {
	target_id: EntityId,
	source_id: EntityId,
	source:    DamageSource,
	dmg:       i32,
}

EventEntityDied :: struct {
	entity_id: EntityId,
}

event_fire :: proc(ev: Event) -> Error {
	evt := ev
	return _handle(&evt)
}

@(private = "file")
_handle :: proc(evt: ^Event) -> Error {
	if LOG_EVENTS do info("%v", evt)
	switch &evt in evt {
	case EventEntityHurt:
		return _entity_hurt(&evt)
	case EventEntityDied:
		return _entity_died(&evt)
	case EventEntityMiss:
		return _entity_miss(&evt)
	case EventTurnStarting:
		return _turn_starting(&evt)
	case EventTurnEnding:
		return _turn_ending(&evt)
	case EventGameOver:
		return _game_over(&evt)
	}
	return nil
}

@(private = "file")
_entity_hurt :: proc(evt: ^EventEntityHurt) -> Error {
	target := entity_or_error(evt.target_id) or_return

	target.hp -= evt.dmg
	fx_spawn_dmg(target.pos, evt.dmg)

	if .IsPlayerControlled in target.meta.flags do target.cmd = Command{}

	if target.hp <= 0 {
		event_fire(EventEntityDied{entity_id = target.id}) or_return
	}
	return nil
}

_entity_miss :: proc(evt: ^EventEntityMiss) -> Error {
	target := entity_or_error(evt.target_id) or_return
	fx_spawn_dmg(target.pos, 0)
	return nil
}

@(private = "file")
_entity_died :: proc(evt: ^EventEntityDied) -> Error {
	deceased := entity_or_error(evt.entity_id) or_return

	state.client.game.enemies_killed += 1
	game_spawn_entity(.Corpse, Entity{pos = deceased.pos})
	if deceased.meta_id == .Firebug {
		iter := prism.aabb_iterator(prism.aabb(Vec2i(deceased.pos) - {1, 1}, Vec2i({3, 3})))
		for pos in prism.aabb_iterate(&iter) {
			tile, valid_tile := tile_at(TileCoord(pos)).?
			fuel: i32 = pos == Vec2i(deceased.pos) ? 14 : 5
			if valid_tile do tile_set_fire(tile, fuel)
		}
	}
	entity_despawn(deceased)

	game_check_lose_condition()

	audio_play(deceased.meta.team == .Players ? .PlayerDeath : .EnemyDeath)

	return nil
}

@(private = "file")
_turn_starting :: proc(evt: ^EventTurnStarting) -> Error {
	state.host.turn_sent_off = false
	state.client.game.turn_complete = false

	tile_handle_turn()
	return nil
}

@(private = "file")
_turn_ending :: proc(evt: ^EventTurnEnding) -> Error {
	for _, &entity in state.client.game.entities {
		entity.meta.flags = entity.meta.flags - {.MovedLastTurn}
		if .MovedThisTurn in entity.meta.flags {
			entity.meta.flags = entity.meta.flags + {.MovedLastTurn}
		}
		entity.meta.flags = entity.meta.flags - {.MovedThisTurn}

		if .IsPlayerControlled in entity.meta.flags || .IsAiControlled in entity.meta.flags {
			entity_add_ap(&entity, 100)
		}

		tile, valid_tile := tile_at(entity.pos).?
		if valid_tile && tile.fire.fuel > 0 && .CanTakeDamage in entity.meta.flags {
			// Take fire damage
			event_fire(EventEntityHurt{target_id = entity.id, dmg = 5, source = .Fire})
		}

		entity.ai.iterations_this_turn = 0
	}
	derived_clear()

	state.client.game.current_turn += 1

	return nil
}

@(private = "file")
_game_over :: proc(evt: ^EventGameOver) -> Error {
	state.client.game.status = .GameOver
	return nil
}
