package main

import "fresnel"
import "prism"

AiBrain :: struct {
	iterations_this_turn: i32,
}

ai_evaluate :: proc(e: ^Entity) {
	e.ai.iterations_this_turn += 1
	state_check_for_infinite_loops()

	if e.ai.iterations_this_turn > 5 {
		err("AI could not find possible command, skipping turn")
		e.cmd = Command {
			type = .Skip,
		}
		return
	}

	target, has_target := q_entities_in_range_of(e.pos, filter_is_player_team)
	if has_target {
		trace("Entity %d trying to attack %v", e.id, target.pos)
		e.cmd = Command {
			type          = .Attack,
			target_entity = target.id,
		}
		return
	}

	if e.cmd.type == .None {
		e.cmd = Command {
			type = .MoveTowardsAllies,
		}
	}
}
