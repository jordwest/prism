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
