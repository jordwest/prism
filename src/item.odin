package main

import "prism"

ItemStack :: struct {
	id:           ItemId,
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
	stored_item.id = ItemId(id)
	return stored_item.id, stored_item, nil
}

item_set_container :: proc(item: ^ItemStack, container_id: ContainerId) {
	item.container_id = container_id
	// TODO: Consolidate stacks in the container here before reset
	// (eg two stacks of 1 potion should become 1 stack of 2)
	// if item_can_combine(item1, item2) { ... }
	containers_reset()
}

item_id_serialize :: proc(s: ^prism.Serializer, item_id: ^ItemId) -> prism.SerializationResult {
	prism.serialize_i32(s, (^i32)(&item_id.id)) or_return
	prism.serialize_i32(s, (^i32)(&item_id.gen)) or_return
	return nil
}
