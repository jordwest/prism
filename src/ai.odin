package main

import "fresnel"
import "prism"

AiBrain :: struct {
	iterations_this_turn: i32,
}

ai_evaluate :: proc(entity: ^Entity) {
	entity.ai.iterations_this_turn += 1
	state_check_for_infinite_loops()

	if entity.ai.iterations_this_turn > 5 {
		warn("AI could not find possible command, skipping turn")
		entity.cmd = Command {
			type = .Skip,
		}
		return
	}

	entity.cmd = _ai_next_cmd(entity)
}

_ai_next_cmd :: proc(e: ^Entity) -> Command {
	target, has_target := q_entities_in_range_of(e.pos, filter_is_player_team)
	if has_target {
		return Command{type = .Attack, target_entity = target.id}
	}

	dmap, err := derived_allies_djikstra_map()
	if err != nil do return Command{type = .Skip}

	_, cost, ok := prism.djikstra_next(dmap, Vec2i(e.pos))
	if !ok do return Command{type = .Skip}
	if cost > 1200 do return Command{type = .Skip}

	return Command{type = .MoveTowardsAllies}
}
