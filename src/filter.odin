package main

filter :: proc(filter_info: EntityFilter, entity: ^Entity) -> bool {
	switch f in filter_info {
	case EntityMetaId:
		return entity.meta_id == f
	case EntityFlags:
		return f in entity.meta.flags
	case Team:
		return entity.meta.team == f
	}

	return false
}

EntityFilter :: union {
	EntityMetaId,
	EntityFlags,
	Team,
}
