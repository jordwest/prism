package main

import "core:math"
import "prism"

Event :: union {
	EventEntityDied,
	EventEntityHurt,
	EventEntityMiss,
	EventEntityHeal,
	EventEntityMove,
	EventEntitySlow,
	EventEntityVisibilityChanged,
	EventTurnStarting,
	EventTurnEnding,
	EventPotionConsume,
	EventPotionActivateAt,
	EventGameOver,
	EventGameWon,
}

EventTurnStarting :: struct {}
EventTurnEnding :: struct {}

EventPotionConsume :: struct {
	item_id:   ItemId,
	entity_id: EntityId,
}

EventPotionActivateAt :: struct {
	item_id:  ItemId,
	pos:      TileCoord,
	consumed: bool,
}

EventEntityHeal :: struct {
	entity_id: EntityId,
	hp:        i32,
}

EventEntitySlow :: struct {
	entity_id: EntityId,
}

DamageSource :: enum {
	Enemy,
	Fire,
}

EventGameOver :: struct {}
EventGameWon :: struct {}

EventEntityMove :: struct {
	entity_id: EntityId,
	pos:       TileCoord,
}

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

EventEntityVisibilityChanged :: struct {
	entity_id: EntityId,
	visible:   bool,
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
	case EventEntityHeal:
		return _entity_heal(&evt)
	case EventEntityMove:
		return _entity_move(&evt)
	case EventEntityVisibilityChanged:
		return _entity_visibility_changed(&evt)
	case EventEntitySlow:
		return _entity_slow(&evt)
	case EventTurnStarting:
		return _turn_starting(&evt)
	case EventTurnEnding:
		return _turn_ending(&evt)
	case EventPotionConsume:
		return _potion_consume(&evt)
	case EventPotionActivateAt:
		return _potion_activate(&evt)
	case EventGameOver:
		return _game_over(&evt)
	case EventGameWon:
		return _game_won(&evt)
	}
	return nil
}

@(private = "file")
_entity_hurt :: proc(evt: ^EventEntityHurt) -> Error {
	target := entity_or_error(evt.target_id) or_return

	target.hp -= evt.dmg
	fx_spawn_dmg(target.pos, evt.dmg)

	if entity_is_current_player(target) do audio_play(.PlayerHurt)

	if .IsPlayerControlled in target.meta.flags {
		// TODO: Don't cancel an attack command when the player's command
		// is to attack this entity and the enemy is in range of the player
		target.cmd = Command{}
	}
	target.t_last_hurt = state.t

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

_entity_heal :: proc(evt: ^EventEntityHeal) -> Error {
	target := entity_or_error(evt.entity_id) or_return

	target.hp = min(target.meta.max_hp, target.hp + evt.hp)

	return nil
}

_entity_move :: proc(evt: ^EventEntityMove) -> Error {
	entity := entity_or_error(evt.entity_id) or_return
	entity.pos = evt.pos
	entity.meta.flags = entity.meta.flags + {.MovedThisTurn}

	// Check win conditions
	game_check_win_condition()

	derived_handle_entity_changed(entity)

	return nil
}

@(private = "file")
_entity_died :: proc(evt: ^EventEntityDied) -> Error {
	deceased := entity_or_error(evt.entity_id) or_return

	state.client.game.enemies_killed += 1
	game_spawn_entity(.Corpse, Entity{pos = deceased.pos})
	if deceased.meta_id == .Firebug {
		tile_create_fireball(deceased.pos, 1.8, 10)
	}
	entity_despawn(deceased)

	game_check_lose_condition()

	if deceased.meta.team == .Players {
		audio_play(entity_is_current_player(deceased) ? .PlayerDeath : .AllyDeath)
	} else {
		audio_play(.EnemyDeath)
	}

	if entity_is_current_player(deceased) || state.client.viewing_entity_id == deceased.id {
		living_player, ok := q_first_living_player_entity().?
		if ok {
			state.client.viewing_entity_id = living_player.id
		}
	}

	return nil
}

@(private = "file")
_entity_slow :: proc(evt: ^EventEntitySlow) -> Error {
	entity := entity_or_error(evt.entity_id) or_return

	eff := &entity.status_effects[.Slowed]
	eff.flags += {.Active}
	eff.turns_remain = math.max(20, eff.turns_remain)
	eff.turns = eff.turns_remain

	fx_add(Fx{type = .SlowedIndicator, lifetime = 2, pos = entity.pos, t0 = state.t})

	return nil
}

@(private = "file")
_entity_visibility_changed :: proc(evt: ^EventEntityVisibilityChanged) -> Error {
	entity := entity_or_error(evt.entity_id) or_return

	if filter_is_enemy(entity) && evt.visible {
		// Enemy became visible, clear all player commands
		for _, &e in state.client.game.entities {
			if e.player_id == nil do continue
			e.cmd = Command{}
			e._local_cmd = nil
		}
	}
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

		entity_turn(&entity)

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

@(private = "file")
_game_won :: proc(evt: ^EventGameWon) -> Error {
	state.client.game.status = .GameWon
	return nil
}

@(private = "file")
_potion_consume :: proc(evt: ^EventPotionConsume) -> Error {
	entity := entity_or_error(evt.entity_id) or_return

	item, item_ok := item(evt.item_id).?
	if !item_ok do return error(ItemNotFound{item_id = evt.item_id})

	if item.container_id != SharedLootContainer {
		return error(
			WrongContainer {
				actual_container = item.container_id,
				expected_container = SharedLootContainer,
				item_id = item.id,
			},
		)
	}

	event_fire(EventPotionActivateAt{item_id = item.id, pos = entity.pos, consumed = true})

	return nil
}

@(private = "file")
_potion_activate :: proc(evt: ^EventPotionActivateAt) -> Error {
	pos := evt.pos

	tile_entities := derived_entities_at(pos)
	entity_at_pos, has_entity_at_pos := tile_entities.obstacle.?

	item, item_ok := item(evt.item_id).?
	if !item_ok do return error(ItemNotFound{item_id = evt.item_id})

	if item.container_id != SharedLootContainer {
		return error(
			WrongContainer {
				actual_container = item.container_id,
				expected_container = SharedLootContainer,
				item_id = item.id,
			},
		)
	}

	switch item.type {
	case PotionType.Fire:
		tile_create_fireball(pos, 2.5, 40)
	case PotionType.Healing:
		if !has_entity_at_pos do break
		event_fire(EventEntityHeal{entity_id = entity_at_pos.id, hp = 40})
	case PotionType.Lethargy:
		if !has_entity_at_pos do break
		event_fire(EventEntitySlow{entity_id = entity_at_pos.id})
	}
	item.count = item.count - 1
	if item.count == 0 do item_despawn(item.id)

	return nil
}
