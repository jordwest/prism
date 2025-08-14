package main

import "prism"

ItemStack :: struct {
	count:        u8,
	type:         ItemTypes,
	container_id: ContainerId,
}

ItemTypes :: union {
	PotionType,
}

PotionType :: enum u8 {
	Healing,
	Fire,
}

ItemTable :: prism.Pool(ItemStack, 4096)

ItemId :: distinct prism.PoolId

item :: proc(item_id: ItemId) -> Maybe(^ItemStack) {
	return prism.pool_get(&state.client.game.items, prism.PoolId(item_id))
}

items_init :: proc() {
	prism.pool_init(&state.client.game.items)
}

item_spawn :: proc(item: ItemStack) -> (ItemId, ^ItemStack, Error) {
	id, stored_item, ok := prism.pool_add(&state.client.game.items, item)
	if !ok do return ItemId{}, nil, error(NoCapacity{})

	return ItemId(id), stored_item, nil
}
