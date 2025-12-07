package simulator

import "core:math/rand"
import "core:mem"

PADDING :: 2

State :: struct {
	curr:                        Grid,
	next:                        Grid,
	generation:                  u64,
	grid_width, grid_height:     int,
	padded_width, padded_height: int,
}

init :: proc(grid_width: int, grid_height: int) -> ^State {
	state := new(State)

	setup_grid(state, grid_width, grid_height)

	randomize(state)

	return state
}

destroy :: proc(state: ^State) {
	if state == nil do return

	grid_destroy(&state.curr)
	grid_destroy(&state.next)

	free(state)
}

randomize :: proc(state: ^State) {
	for y in 1 ..= state.grid_height {
		row_offset := y * state.padded_width
		for x in 1 ..= state.grid_width {
			state.curr.cells[row_offset + x].state = rand.float32() > 0.5 ? .Alive : .Dead
		}
	}
}

step :: proc(state: ^State) #no_bounds_check {
	update_ghost_cells(state)

	for y in 1 ..= state.grid_height {
		curr_above_ptr, curr_current_ptr, curr_below_ptr := grid_get_adjacent_row_ptrs(
			&state.curr,
			y,
		)
		next_row_ptr := grid_get_row_ptr(&state.next, y)

		for x in 1 ..= state.grid_width {
			neighbor_count: int
			neighbor_count +=
				int(curr_above_ptr[x - 1].state) +
				int(curr_above_ptr[x].state) +
				int(curr_above_ptr[x + 1].state)
			neighbor_count +=
				int(curr_current_ptr[x - 1].state) + int(curr_current_ptr[x + 1].state)
			neighbor_count +=
				int(curr_below_ptr[x - 1].state) +
				int(curr_below_ptr[x].state) +
				int(curr_below_ptr[x + 1].state)

			curr_state := curr_current_ptr[x].state
			next_state := rules_get_next(neighbor_count, curr_state)
			next_row_ptr[x].state = next_state
		}
	}

	state.curr, state.next = state.next, state.curr
	state.generation += 1
}

@(private)
setup_grid :: proc(state: ^State, grid_width: int, grid_height: int) {
	state.grid_width = grid_width
	state.grid_height = grid_height
	state.padded_width = grid_width + PADDING
	state.padded_height = grid_height + PADDING

	grid_init(&state.curr, state.padded_width, state.padded_height)
	grid_init(&state.next, state.padded_width, state.padded_height)
}

@(private)
update_ghost_cells :: proc(state: ^State) #no_bounds_check {
	grid := &state.curr

	/*for y in 1 ..= state.grid_height {
		row_start := y * state.padded_width
		grid_set_cell(grid, row_start, grid_get_cell(grid, row_start + state.grid_width)) // Left ghost cell gets rightmost real column
		grid_set_cell(
			grid,
			row_start + (state.padded_width - 1),
			grid_get_cell(grid, row_start + 1),
		) // Right ghost cell gets leftmost real column
	}*/

	for y in 1 ..= state.grid_height {
		row := grid_get_row_ptr(grid, y)
		row[0] = row[state.grid_width] // Left ghost = rightmost real
		row[state.padded_width - 1] = row[1] // Right ghost = leftmost real
	}

	top_ghost_row_dest := grid_get_row_ptr(grid, 0)
	bottom_real_row_src := grid_get_row_ptr(grid, state.grid_height)
	mem.copy(top_ghost_row_dest, bottom_real_row_src, state.padded_width) // Copy bottom real row to top ghost row

	bottom_ghost_row_dest := grid_get_row_ptr(grid, state.padded_height - 1)
	top_real_row_src := grid_get_row_ptr(grid, 1)
	mem.copy(bottom_ghost_row_dest, top_real_row_src, state.padded_width) // Copy top real row to bottom ghost row
}
