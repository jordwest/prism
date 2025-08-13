package main

import "core:mem"

TurnOutcome :: enum {
	TurnComplete,
	AwaitingInput,
	Error,
}

turn_evaluate_all :: proc() -> Error {
	outcome, e := turn_evaluate()
	if e != nil do return e

	return nil
}

turn_evaluate :: proc() -> (outcome: TurnOutcome, e: Error) {
	awaiting_input := false
	// Execute any pending player commands first
	for _, &entity in state.client.game.entities {
		_, is_player := entity.player_id.?
		if !is_player do continue

		outcome := command_execute_all(&entity)

		switch outcome {
		case .NeedsActionPoints:
			continue
		case .CommandFailed:
			awaiting_input = true
		case .NeedsInput:
			awaiting_input = true
		case .Ok:
			// Current command should have executed until
			// it has been exhausted and is waiting on input
			// or action points, so we should never get an
			// `Ok` from command_execute_all
			return .Error, error(InvariantError{})
		}
	}

	if awaiting_input do return .AwaitingInput, nil

	// Now evaluate all AI
	for _, &entity in state.client.game.entities {
		if .IsAiControlled in entity.meta.flags {
			outcome := command_execute_all_ai(&entity)

			switch outcome {
			case .NeedsActionPoints:
				continue
			case .CommandFailed:
				return .Error, error(InvariantError{})
			case .NeedsInput:
				return .Error, error(InvariantError{})
			case .Ok:
				// Current command should have executed until
				// it has been exhausted and is waiting on input
				// or action points, so we should never get an
				// `Ok` from command_execute_all
				return .Error, error(InvariantError{})
			}
		}
	}

	// Player input complete, AI would be executed here
	trace("New turn")
	turn_complete()

	return .TurnComplete, nil
}

turn_complete :: proc() {
	state.client.game.turn_complete = true
}

turn_advance :: proc() {
	for _, &entity in state.client.game.entities {
		entity.meta.flags = entity.meta.flags - {.MovedLastTurn}
		if .MovedThisTurn in entity.meta.flags {
			entity.meta.flags = entity.meta.flags + {.MovedLastTurn}
		}
		entity.meta.flags = entity.meta.flags - {.MovedThisTurn}

		if .IsPlayerControlled in entity.meta.flags || .IsAiControlled in entity.meta.flags {
			entity_add_ap(&entity, 100)
		}

		entity.ai.iterations_this_turn = 0
	}
	derived_clear()
	state.client.game.current_turn += 1

	tile_handle_turn()
}
