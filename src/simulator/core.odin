package simulator

import "core:math/rand"
import "core:mem"

GRID_PADDING :: 2

Simulation :: struct {
	current_state:               Grid,
	next_state:                  Grid,
	generation:                  u64,
	grid_width, grid_height:     int,
	padded_width, padded_height: int,
}

init :: proc(grid_width: int, grid_height: int) -> (simulation: ^Simulation) {
	simulation = new(Simulation)

	setup_grids(simulation, grid_width, grid_height)

	randomize(simulation)

	return simulation
}

destroy :: proc(simulation: ^Simulation) {
	if simulation == nil do return

	grid_destroy(&simulation.current_state)
	grid_destroy(&simulation.next_state)

	free(simulation)
}

randomize :: proc(simulation: ^Simulation) {
	for row_idx in 1 ..= simulation.grid_height {
		row_offset := row_idx * simulation.padded_width
		for col_idx in 1 ..= simulation.grid_width {
			random_cell_state := rand.float32() > 0.5 ? CellState.Alive : CellState.Dead
			simulation.current_state.cells[row_offset + col_idx].state = random_cell_state
		}
	}
}

step :: proc(simulation: ^Simulation) #no_bounds_check {
	update_ghost_cells(simulation)

	for row_idx in 1 ..= simulation.grid_height {
		above_row_ptr, current_row_ptr, below_row_ptr := grid_get_adjacent_row_ptrs(
			&simulation.current_state,
			row_idx,
		)
		next_grid_row_ptr := grid_get_row_ptr(&simulation.next_state, row_idx)

		for col_idx in 1 ..= simulation.grid_width {
			neighbor_count: int
			neighbor_count +=
				int(above_row_ptr[col_idx - 1].state) +
				int(above_row_ptr[col_idx].state) +
				int(above_row_ptr[col_idx + 1].state)
			neighbor_count +=
				int(current_row_ptr[col_idx - 1].state) + int(current_row_ptr[col_idx + 1].state)
			neighbor_count +=
				int(below_row_ptr[col_idx - 1].state) +
				int(below_row_ptr[col_idx].state) +
				int(below_row_ptr[col_idx + 1].state)

			current_cell_state := current_row_ptr[col_idx].state
			next_cell_state := rules_get_next(neighbor_count, current_cell_state)
			next_grid_row_ptr[col_idx].state = next_cell_state
		}
	}

	simulation.current_state, simulation.next_state =
		simulation.next_state, simulation.current_state
	simulation.generation += 1
}

@(private)
setup_grids :: proc(simulation: ^Simulation, grid_width: int, grid_height: int) {
	simulation.grid_width = grid_width
	simulation.grid_height = grid_height
	simulation.padded_width = grid_width + GRID_PADDING
	simulation.padded_height = grid_height + GRID_PADDING

	grid_init(&simulation.current_state, simulation.padded_width, simulation.padded_height)
	grid_init(&simulation.next_state, simulation.padded_width, simulation.padded_height)
}

@(private)
update_ghost_cells :: proc(simulation: ^Simulation) #no_bounds_check {
	current_grid := &simulation.current_state

	for row_idx in 1 ..= simulation.grid_height {
		current_row_ptr := grid_get_row_ptr(current_grid, row_idx)
		current_row_ptr[0] = current_row_ptr[simulation.grid_width] // Left ghost = rightmost real
		current_row_ptr[simulation.padded_width - 1] = current_row_ptr[1] // Right ghost = leftmost real
	}

	top_ghost_row_ptr := grid_get_row_ptr(current_grid, 0)
	bottom_real_row_ptr := grid_get_row_ptr(current_grid, simulation.grid_height)
	mem.copy(top_ghost_row_ptr, bottom_real_row_ptr, simulation.padded_width) // Copy bottom real row to top ghost row

	bottom_ghost_row_ptr := grid_get_row_ptr(current_grid, simulation.padded_height - 1)
	top_real_row_ptr := grid_get_row_ptr(current_grid, 1)
	mem.copy(bottom_ghost_row_ptr, top_real_row_ptr, simulation.padded_width) // Copy top real row to bottom ghost row
}
