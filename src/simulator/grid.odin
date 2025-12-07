package simulator

Grid :: struct {
	width:  int,
	height: int,
	cells:  []Cell,
}

grid_init :: proc(grid: ^Grid, grid_width: int, grid_height: int) {
	grid.width = grid_width
	grid.height = grid_height
	grid.cells = make([]Cell, grid.width * grid.height)
}

grid_destroy :: proc(grid: ^Grid) {
	delete(grid.cells)
}

grid_get_adjacent_row_ptrs :: #force_inline proc(
	grid: ^Grid,
	index: int,
) -> (
	above: [^]Cell,
	current: [^]Cell,
	below: [^]Cell,
) #no_bounds_check {
	above = raw_data(grid.cells[(index - 1) * grid.width:])
	current = raw_data(grid.cells[index * grid.width:])
	below = raw_data(grid.cells[(index + 1) * grid.width:])
	return
}

grid_get_row_ptr :: #force_inline proc(grid: ^Grid, index: int) -> [^]Cell #no_bounds_check {
	return raw_data(grid.cells[index * grid.width:])
}
