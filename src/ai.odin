package main

import "fresnel"
import "prism"

AiBrain :: struct {
	iterations_this_turn: i32,
}

ai_evaluate :: proc(e: ^Entity) {
	e.ai.iterations_this_turn += 1
	state_check_for_infinite_loops()

	fresnel.log_i32("Entity id", i32(e.id))
	trace("Evaluating AI for")

	if e.ai.iterations_this_turn > 5 {
		err("AI could not find possible command, skipping turn")
		e.cmd = Command {
			type = .Skip,
		}
		return
	}

	target, has_target := q_entities_in_range_of(e.pos, filter_is_player_team)
	if has_target {
		info("TRY TO ATTACK")
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
