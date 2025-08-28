package main

UiMode :: union {
	UiActivatingItem,
	UiThrowingItem,
}

UiActivatingItem :: struct {
	item_id: ItemId,
}
UiThrowingItem :: struct {
	item_id: ItemId,
	pos:     TileCoord,
}

UiState :: struct {
	mode:              UiMode,
	current_menu:      UiMenu,
	input_destination: UiInputDestination,
}

UiMenu :: enum {
	MainMenu,
	Join,
	Lobby,
}

// Which input is currently visible - determines which state is updated when the input is changed
UiInputDestination :: enum {
	None,
	DisplayName,
	JoinURL,
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
