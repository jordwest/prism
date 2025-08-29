package main

import "core:container/queue"
import "core:math"
import "prism"

// Mark all tiles in visible range as "seen"
vision_update :: proc() {

	for &tile in state.client.game.tiles.data {
		// Clear visibile tiles as they'll be set in next loop
		tile.flags -= {.Visible}

		when FOG_OF_WAR_OFF {
			tile.flags += {.Visible, .Seen}
		}
	}

	for _, p in state.client.game.players {
		entity, ok := entity(p.player_entity_id).?
		if !ok do continue

		tile, valid_tile := tile_at(entity.pos).?
		if !valid_tile do continue

		// Reveal player position
		_reveal(tile)

		for direction in prism.Cardinal {
			quadrant := Quadrant {
				direction = direction,
				origin    = Vec2i(entity.pos),
			}
			first_row := Row {
				depth       = 1,
				quadrant    = quadrant,
				start_slope = -1,
				end_slope   = 1,
			}

			_scan(first_row)
		}
	}

	for _, &entity in state.client.game.entities {
		tile, ok := tile_at(entity.pos).?
		if !ok do continue

		if .IsVisibleToPlayers in entity.meta.flags && .Visible not_in tile.flags {
			entity.meta.flags -= {.IsVisibleToPlayers}
			event_fire(EventEntityVisibilityChanged{entity_id = entity.id, visible = false})
		} else if .IsVisibleToPlayers not_in entity.meta.flags && .Visible in tile.flags {
			entity.meta.flags += {.IsVisibleToPlayers}
			event_fire(EventEntityVisibilityChanged{entity_id = entity.id, visible = true})
		}
	}

	state.client.game.derived.up_to_date += {.FieldOfView}
}

@(private)
_reveal :: proc(tile: ^TileData) {
	tile.flags = tile.flags + {.Seen, .Visible}
}

@(private)
_queue_buf: [100]Row

////////////////// Symmetric shadowcasting \\\\\\\\\\\\\\\
//////// from https://www.albertford.com/shadowcasting \\\

@(private)
_scan :: proc(start_row: Row, max_depth: i32 = 12) {
	iterations := 0

	row_queue: queue.Queue(Row)
	queue.init_from_slice(&row_queue, _queue_buf[:])
	queue.push_back(&row_queue, start_row)

	for {
		row, ok := queue.pop_front_safe(&row_queue)
		if !ok do break

		iterations += 1
		if iterations >= 100 {
			trace("Iteration limit hit")
			return
		}

		iter := _row_iterator(row)
		prev_cell: Maybe(FovCell) = nil
		//     prev_tile = None
		for cell in _row_iterate(&iter) {
			iterations += 1
			if iterations >= 1000 {
				trace("Iteration limit hit")
				return
			}

			if _is_wall(cell) || _is_symmetric(row, cell) {
				if tile, ok := cell.tile.?; ok do _reveal(tile)
			}
			if _is_wall(prev_cell) && _is_floor(cell) {
				row.start_slope = _slope(cell)
			}
			if _is_floor(prev_cell) && _is_wall(cell) && row.depth < max_depth {
				next_row := _next_row(row)
				next_row.end_slope = _slope(cell)
				queue.push_back(&row_queue, next_row)
			}
			prev_cell = cell
		}
		if _is_floor(prev_cell) && row.depth < max_depth {
			next_row := _next_row(row)
			queue.push_back(&row_queue, next_row)
		}
	}
}

@(private)
_slope :: proc(cell: FovCell) -> f32 {
	return (2 * f32(cell.col) - 1) / (2 * f32(cell.depth))
}

@(private)
_is_wall :: proc(cell_opt: Maybe(FovCell)) -> bool {
	cell, cell_set := cell_opt.?
	if !cell_set do return false

	tile, valid_tile := cell.tile.?
	if !valid_tile do return true // Out of bounds tile

	return .BlocksVision in tile.flags
}

@(private)
_is_floor :: proc(cell_opt: Maybe(FovCell)) -> bool {
	cell, cell_set := cell_opt.?
	if !cell_set do return false

	tile, valid_tile := cell.tile.?
	if !valid_tile do return false // Out of bounds tile

	return .BlocksVision not_in tile.flags
}

@(private)
_is_symmetric :: proc(row: Row, cell: FovCell) -> bool {
	tile, ok := cell.tile.?
	if !ok do return false // Out of bounds tile

	return(
		f32(cell.col) >= f32(row.depth) * row.start_slope &&
		f32(cell.col) <= f32(row.depth) * row.end_slope \
	)
}

@(private)
Row :: struct {
	quadrant:    Quadrant,
	depth:       i32,
	start_slope: f32,
	end_slope:   f32,
}

@(private)
RowIter :: struct {
	quadrant: Quadrant,
	max_col:  i32,
	depth:    i32,
	col:      i32,
}

@(private)
FovCell :: struct {
	depth: i32,
	col:   i32,
	tile:  Maybe(^TileData),
}

@(private)
Quadrant :: struct {
	origin:    [2]i32,
	direction: prism.Cardinal,
}

@(private)
_quadrant_transform :: proc(quadrant: ^Quadrant, row: i32, col: i32) -> [2]i32 {
	switch quadrant.direction {
	case .South:
		return {quadrant.origin.x + col, quadrant.origin.y + row}
	case .North:
		return {quadrant.origin.x + col, quadrant.origin.y - row}
	case .East:
		return {quadrant.origin.x + row, quadrant.origin.y + col}
	case .West:
		return {quadrant.origin.x - row, quadrant.origin.y + col}
	}
	return {0, 0}
}

@(private)
_next_row :: proc(row: Row) -> Row {
	return Row {
		depth = row.depth + 1,
		quadrant = row.quadrant,
		start_slope = row.start_slope,
		end_slope = row.end_slope,
	}
}

@(private)
_row_iterator :: proc(row: Row) -> RowIter {
	return RowIter {
		quadrant = row.quadrant,
		depth = row.depth,
		col = i32(math.floor(f32(row.depth) * row.start_slope + 0.5)),
		max_col = i32(math.ceil(f32(row.depth) * row.end_slope - 0.5)),
	}
}

@(private)
_row_iterate :: proc(row_iter: ^RowIter) -> (FovCell, i32, bool) {
	if row_iter.col > row_iter.max_col do return {}, row_iter.col, false // Iteration complete

	col := row_iter.col
	row_iter.col += 1

	coord := TileCoord(_quadrant_transform(&row_iter.quadrant, row_iter.depth, col))

	return FovCell{depth = row_iter.depth, col = col, tile = tile_at(coord)}, col, true
}
