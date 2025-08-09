package main

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
		if is_player {
			outcome := command_execute_all(&entity)

			trace("Outcome %d %v", entity.id, outcome)

			switch outcome {
			case .NeedsActionPoints:
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
	}

	if awaiting_input do return .AwaitingInput, nil

	// Player input complete, AI would be executed here
	trace("New turn")
	turn_complete()

	return .TurnComplete, nil
}

turn_complete :: proc() {
	state.client.game.turn_complete = true
}
