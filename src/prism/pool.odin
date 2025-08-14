package prism

import "core:container/queue"
import "core:mem"

PoolId :: struct #packed {
	id:  i32,
	gen: i32,
}

Pool :: struct($T: typeid, $Capacity: i32) {
	_holes_container: [Capacity + 1]PoolId,
	holes:            queue.Queue(PoolId),
	next_id:          i32,
	items:            [Capacity + 1]T,
	generations:      [Capacity + 1]i32,
}

PoolIterator :: struct($T: typeid, $Capacity: i32) {
	pool: ^Pool(T, Capacity),
	i:    i32,
}

pool_iterator :: proc(pool: ^Pool($T, $Capacity)) -> PoolIterator(T, Capacity) {
	return PoolIterator(T, Capacity){pool = pool, i = 0}
}

pool_iterate :: proc(iter: ^PoolIterator($T, $Capacity)) -> (data: ^T, id: PoolId, ok: bool) {
	for {
		i: i32 = iter.i
		iter.i += 1
		if i >= iter.pool.next_id do return nil, {}, false
		if i >= Capacity + 1 do return nil, {}, false

		if iter.pool.generations[i] > 0 {
			id := PoolId {
				id  = i,
				gen = iter.pool.generations[i],
			}
			return &iter.pool.items[i], id, true
		}
	}
}

pool_init :: proc(arr: ^Pool($T, $Capacity)) {
	queue.init_from_slice(&arr.holes, arr._holes_container[:])
	arr.next_id = 1
}

pool_add :: proc(arr: ^Pool($T, $Capacity), item: T) -> (PoolId, ^T, bool) {
	old_slot, has_old_slot := queue.pop_front_safe(&arr.holes)
	if has_old_slot {
		arr.generations[old_slot.id] = old_slot.gen + 1
		arr.items[old_slot.id] = item
		return PoolId{id = old_slot.id, gen = old_slot.gen + 1}, &arr.items[old_slot.id], true
	}

	// No free slots

	if arr.next_id >= Capacity + 1 do return {}, nil, false

	// Use new slot

	id := PoolId {
		id  = arr.next_id,
		gen = 1,
	}
	arr.items[id.id] = item
	arr.next_id += 1
	arr.generations[id.id] = id.gen
	return id, &arr.items[id.id], true
}

pool_get :: proc(arr: ^Pool($T, $Capacity), id: PoolId) -> Maybe(^T) {
	if arr.generations[id.id] != id.gen do return nil
	return &arr.items[id.id]
}

pool_delete :: proc(arr: ^Pool($T, $Capacity), id: PoolId) -> Maybe(T) {
	if id.gen == 0 do return nil
	if arr.generations[id.id] != id.gen do return nil

	item := arr.items[id.id]
	arr.items[id.id] = {}
	arr.generations[id.id] = 0

	if id.id == arr.next_id - 1 {
		arr.next_id -= 1
		// Can just take the id out of use, no need to create a hole
		return item
	}

	queue.push_back(&arr.holes, id)

	return item
}
