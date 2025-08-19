package main

import "prism"

Event :: union {
	EventEntityDied,
	EventEntityHurt,
	EventEntityMiss,
	EventEntityHeal,
	EventTurnStarting,
	EventTurnEnding,
	EventPotionConsume,
	EventPotionActivateAt,
	EventGameOver,
}

EventTurnStarting :: struct {}
EventTurnEnding :: struct {}

EventPotionConsume :: struct {
	item_id:   ItemId,
	entity_id: EntityId,
}

EventPotionActivateAt :: struct {
	item_id: ItemId,
	pos:     TileCoord,
}

EventEntityHeal :: struct {
	entity_id: EntityId,
	hp:        i32,
}

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
	case EventEntityHeal:
		return _entity_heal(&evt)
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

	event_fire(EventPotionActivateAt{item_id = item.id, pos = entity.pos})

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
	}
	item.count = item.count - 1
	if item.count == 0 do item_despawn(item.id)

	return nil
}
