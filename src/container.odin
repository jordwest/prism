package main

import "core:container/intrusive/list"
import "core:mem"
import "prism"

Containers :: struct {
	index: map[ContainerId]ContainerList,
}

@(private = "file")
ContainerList :: list.List

@(private = "file")
ContainerNode :: struct {
	node:    list.Node,
	item_id: ItemId,
}

ContainerId :: union {
	ItemId,
	EntityId,
	TileCoord,
}

ContainerIterator :: struct {
	list_iter: list.Iterator(ContainerNode),
}

containers_init :: proc() -> Error {
	e: mem.Allocator_Error
	state.client.game.containers.index, e = make(
		map[ContainerId]ContainerList,
		512,
		allocator = arena_containers.allocator,
	)
	if e != nil do return error(e)
	return nil
}

containers_reset :: proc() {
	mem.arena_free_all(&arena_containers.arena)

	state.client.game.containers.index = make(
		map[ContainerId]ContainerList,
		512,
		allocator = arena_containers.allocator,
	)

	// TODO: Move iteration to item.odin
	item_iterator := prism.pool_iterator(&state.client.game.items)
	for item, item_id in prism.pool_iterate(&item_iterator) {
		switch cid in item.container_id {
		case EntityId:
			trace("Item in inventory of %d", cid)
		case TileCoord:
			trace("Item contained in tile %d", cid)
		case ItemId:
			trace("Item contained by item %v", cid)
		case nil:
			trace("Item not contained")
		}
		if item.container_id != nil {
			existing_list, ok := &state.client.game.containers.index[item.container_id]
			if !ok {
				state.client.game.containers.index[item.container_id] = list.List{}
				existing_list = &state.client.game.containers.index[item.container_id]
			}

			new_node := new(ContainerNode, allocator = arena_containers.allocator)
			new_node.item_id = ItemId(item_id)

			list.push_back(existing_list, &new_node.node)
		}
		// if item.container
		// Item
	}
}

container_iterator :: proc(container_id: ContainerId) -> ContainerIterator {
	index, ok := &state.client.game.containers.index[container_id]
	if !ok do return ContainerIterator{}

	return ContainerIterator{list_iter = list.iterator_head(index^, ContainerNode, "node")}
}

container_iterate :: proc(iterator: ^ContainerIterator) -> (^ItemStack, ItemId, bool) {
	for {
		node, ok := list.iterate_next(&iterator.list_iter)
		if !ok do return nil, ItemId{}, false

		item, item_exists := item(node.item_id).?
		if !item_exists {
			warn("Invalid item id %d in container index", node.item_id)
			continue
		}

		return item, node.item_id, true
	}
}
