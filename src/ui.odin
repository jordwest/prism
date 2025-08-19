package main

UiMode :: union {
	UiActivatingItem,
}

UiActivatingItem :: struct {
	item_id: ItemId,
}

UiState :: struct {
	mode: UiMode,
}

ui_clear_mode :: proc() {
	state.client.ui.mode = nil
}

ui_mode :: proc() -> UiMode {
	return state.client.ui.mode
}

ui_replace_mode :: proc(new_mode: UiMode, toggle: bool = false) {
	// Toggle mode off if already the same
	if toggle && state.client.ui.mode == new_mode {
		state.client.ui.mode = nil
		return
	}

	state.client.ui.mode = new_mode
}
