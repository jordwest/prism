package main

import "core:mem"

TurnOutcome :: enum {
	TurnComplete,
	AwaitingInput,
	AwaitingAnimation,
	Error,
}

turn_evaluate :: proc() -> (outcome: TurnOutcome, e: Error) {
	if state.client.game.turn_complete do return .TurnComplete, nil

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
		case .WaitForAnimation:
			log_entry_delay_processing_for_animation()
			return .AwaitingAnimation, nil
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
		if .IsAiControlled not_in entity.meta.flags do continue

		outcome := command_execute_all_ai(&entity)
		trace("Outcome for %d is %w", entity.id, outcome)

		switch outcome {
		case .NeedsActionPoints:
			continue
		case .CommandFailed:
			return .Error, error(InvariantError{})
		case .NeedsInput:
			return .Error, error(InvariantError{})
		case .WaitForAnimation:
			log_entry_delay_processing_for_animation()
			return .AwaitingAnimation, nil
		case .Ok:
			// Current command should have executed until
			// it has been exhausted and is waiting on input
			// or action points, so we should never get an
			// `Ok` from command_execute_all
			return .Error, error(InvariantError{})
		}
	}

	// Player input complete, AI would be executed here
	turn_complete()

	return .TurnComplete, nil
}

log_entry_delay_processing_for_animation :: proc(
	/* delay_length: DelayLength enum ? */
) {
	state.client.log_entry_replay_state = .AwaitingAnimation
	state.client.t_evaluate_turns_after = state.t + ANIMATION_DELAY
	trace("Delay at %.3f until %.3f", state.t, state.client.t_evaluate_turns_after)
}

turn_complete :: proc() {
	state.client.game.turn_complete = true
}

turn_host_frame :: proc() {
	// HOST ONLY: Sends off the turn complete event to all clients
	if state.client.game.turn_complete &&
	   !state.host.turn_sent_off &&
	   state.t - state.host.last_turn_at >= TURN_DELAY {
		state.host.turn_sent_off = true
		state.host.last_turn_at = state.t

		host_log_entry(LogEntryAdvanceTurn{})
	}
}
