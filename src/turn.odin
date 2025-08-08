package main

TurnOutcome :: enum {
	Ok,
	Error,
	AwaitingInput,
}

turn_evaluate_all :: proc() -> Error {
	outcome: TurnOutcome = .Ok
	e: Error

	for i := 0; outcome == .Ok; i += 1 {
		outcome, e = turn_evaluate()
		if e != nil do return e
		if i >= 100 do return error(TooManyIterations{})
	}

	return nil
}

turn_evaluate :: proc() -> (outcome: TurnOutcome, e: Error) {
	// Execute any pending player commands first
	for _, &entity in state.client.game.entities {
		_, is_player := entity.player_id.?
		if is_player {
			outcome := command_execute_all(&entity)

			trace("Outcome %d %v", entity.id, outcome)

			switch outcome {
			case .NeedsActionPoints:
			case .AwaitingNextTurn:
			case .CommandFailed:
				return .AwaitingInput, nil
			case .NeedsInput:
				return .AwaitingInput, nil
			case .Ok:
				return .Error, error(InvariantError{})
			}
		}
	}

	// Player input complete, AI would be executed here
	trace("New turn")
	turn_complete()

	return .Ok, nil
}

turn_complete :: proc() {
	for _, &entity in state.client.game.entities {
		entity.action_points += 100
	}
}
