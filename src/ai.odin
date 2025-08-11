package main

import "prism"

AiBrain :: struct {
	iterations_this_turn: i32,
}

ai_evaluate :: proc(e: ^Entity) {
	e.ai.iterations_this_turn += 1
	state_check_for_infinite_loops()

	rng := prism.rand_splitmix_create(GAME_SEED, RNG_AI)
	prism.rand_splitmix_add_i32(&rng, i32(e.id))
	prism.rand_splitmix_add_i32(&rng, state.client.game.current_turn)

	trace("Evaluating AI for %d", e.id)

	if e.ai.iterations_this_turn > 5 {
		err("AI could not find possible command, skipping turn")
		e.cmd = Command {
			type = .Skip,
		}
		return
	}

	if e.cmd.type == .None {
		e.cmd = Command {
			type = .Move,
			pos  = prism.rand_splitmix_get_tilecoord_in_aabb(
				&rng,
				prism.Aabb(i32){x1 = 0, y1 = 0, x2 = LEVEL_WIDTH, y2 = LEVEL_HEIGHT},
			),
		}
	}
}
