package simulator

import "../config"
import "core:math/rand"
import "core:mem"

@(private)
RULES_LUT: [32]u8

Grid :: struct {
	data: []u8,
}

State :: struct {
	curr:           Grid,
	next:           Grid,
	generation:     u64,
	grid_w, grid_h: int,
	pad_w, pad_h:   int,
}

init :: proc(width: int, height: int) -> (s: State, err: mem.Allocator_Error) {
	init_rules_lut()
	s.grid_w = width
	s.grid_h = height
	s.pad_w = width + 2
	s.pad_h = height + 2
	s.curr.data = make([]u8, s.pad_w * s.pad_h) or_return
	s.next.data = make([]u8, s.pad_w * s.pad_h) or_return
	randomize(&s)
	return
}

destroy :: proc(s: ^State) {
	delete(s.curr.data)
	delete(s.next.data)
}

randomize :: proc(s: ^State) {
	for y in 1 ..= s.grid_h {
		offset := y * s.pad_w
		for x in 1 ..= s.grid_w {
			// ~20% chance of being alive
			s.curr.data[offset + x] = rand.float32() > 0.5 ? 1 : 0
		}
	}
}

step :: proc(s: ^State) #no_bounds_check {
	update_ghost_cells(s)

	// Iterate through rows
	for y in 1 ..= s.grid_h {
		// Calculate offsets for relative rows
		offset_up := (y - 1) * s.pad_w
		offset_curr := y * s.pad_w
		offset_down := (y + 1) * s.pad_w

		// Get pointers to the rows
		row_up := raw_data(s.curr.data[offset_up:])
		row_curr := raw_data(s.curr.data[offset_curr:])
		row_down := raw_data(s.curr.data[offset_down:])

		// Get pointer to the next row
		row_next := raw_data(s.next.data[offset_curr:])

		// Iterate through columns
		for x in 1 ..= s.grid_w {
			// Calculate sum of neighbors
			n_sum := 0
			n_sum += int(row_up[x - 1]) + int(row_up[x]) + int(row_up[x + 1])
			n_sum += int(row_curr[x - 1]) + int(row_curr[x + 1])
			n_sum += int(row_down[x - 1]) + int(row_down[x]) + int(row_down[x + 1])

			// Map cell state and sum of neighbors to LUT index
			is_alive := int(row_curr[x])
			lut_index := (n_sum * 2) + is_alive
			// Get new state from LUT
			row_next[x] = RULES_LUT[lut_index]
		}
	}

	// Swap pointers and increment generation
	s.curr, s.next = s.next, s.curr
	s.generation += 1
}

@(private)
update_ghost_cells :: proc(s: ^State) #no_bounds_check {
	grid := &s.curr

	// Iterate through rows
	for y in 1 ..= s.grid_h {
		row_start := y * s.pad_w
		// Left ghost cell gets rightmost real column
		grid.data[row_start] = grid.data[row_start + s.grid_w]
		// Right ghost cell gets leftmost real column
		grid.data[row_start + (s.pad_w - 1)] = grid.data[row_start + 1]
	}

	// Copy bottom real row to top ghost row
	top_dest := &grid.data[0]
	bottom_src := &grid.data[s.grid_h * s.pad_w]
	mem.copy(top_dest, bottom_src, s.pad_w)

	// Copy top real row to bottom ghost row
	bottom_dest := &grid.data[(s.pad_h - 1) * s.pad_w]
	top_src := &grid.data[1 * s.pad_w]
	mem.copy(bottom_dest, top_src, s.pad_w)
}

@(private)
init_rules_lut :: proc() {
	for neighbors in 0 ..= 8 {
		for state in 0 ..= 1 {
			alive := false
			if state == 1 {
				if neighbors == 2 || neighbors == 3 do alive = true
			} else {
				if neighbors == 3 do alive = true
			}
			idx := (neighbors * 2) + state
			RULES_LUT[idx] = alive ? 1 : 0
		}
	}
}
