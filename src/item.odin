package main

import "prism"

ItemStack :: struct {
	id:           ItemId,
	count:        i32,
	type:         ItemTypes,
	container_id: ContainerId,
}

ItemTypes :: union {
	PotionType,
}

PotionType :: enum u8 {
	Healing,
	Lethargy,
	Fire,
}

ItemTable :: prism.Pool(ItemStack, 4096)

ItemId :: distinct prism.PoolId

item :: proc(item_id: ItemId) -> Maybe(^ItemStack) {
	return prism.pool_get(&state.client.game.items, prism.PoolId(item_id))
}
item_or_error :: proc(item_id: ItemId) -> (^ItemStack, Error) {
	item, ok := item(item_id).?
	if !ok do return nil, error(ItemNotFound{item_id = item_id})
	return item, nil
}

items_init :: proc() {
	prism.pool_init(&state.client.game.items)
}

items_reset :: proc() {
	prism.pool_clear(&state.client.game.items)
}

// If in_batch is true, you are expected to call containers_reset after spawning all entities
item_spawn :: proc(item: ItemStack, in_batch := false) -> (ItemId, ^ItemStack, Error) {
	id, stored_item, ok := prism.pool_add(&state.client.game.items, item)
	if !ok do return ItemId{}, nil, error(NoCapacity{})
	stored_item.id = ItemId(id)
	if !in_batch && stored_item.container_id != nil do containers_reset()
	return stored_item.id, stored_item, nil
}

item_despawn :: proc(item_id: ItemId) {
	prism.pool_delete(&state.client.game.items, prism.PoolId(item_id))
	containers_reset()
}

item_set_container :: proc(item: ^ItemStack, container_id: ContainerId) {
	// Check container to see if there's already the same item
	iter := container_iterator(container_id)
	for other_item in container_iterate(&iter) {
		// TODO: Limit stack size?
		if other_item.type == item.type {
			other_item.count += item.count
			item_despawn(item.id)

			containers_reset()
			return
		}
	}

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
