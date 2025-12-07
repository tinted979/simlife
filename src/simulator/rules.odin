package simulator

RULES_LUT_SIZE :: 32

@(private)
RULES_LUT: [RULES_LUT_SIZE]CellState = {
	// neighbor_count = 0
	.Dead, // index 0: dead + 0 neighbors = dead
	.Dead, // index 1: alive + 0 neighbors = dead (underpopulation)

	// neighbor_count = 1
	.Dead, // index 2: dead + 1 neighbor = dead
	.Dead, // index 3: alive + 1 neighbor = dead (underpopulation)

	// neighbor_count = 2
	.Dead, // index 4: dead + 2 neighbors = dead
	.Alive, // index 5: alive + 2 neighbors = ALIVE (survival)

	// neighbor_count = 3
	.Alive, // index 6: dead + 3 neighbors = ALIVE (birth)
	.Alive, // index 7: alive + 3 neighbors = ALIVE (survival)

	// neighbor_count = 4
	.Dead, // index 8: dead + 4 neighbors = dead
	.Dead, // index 9: alive + 4 neighbors = dead (overpopulation)

	// neighbor_count = 5
	.Dead, // index 10: dead + 5 neighbors = dead
	.Dead, // index 11: alive + 5 neighbors = dead (overpopulation)

	// neighbor_count = 6
	.Dead, // index 12: dead + 6 neighbors = dead
	.Dead, // index 13: alive + 6 neighbors = dead (overpopulation)

	// neighbor_count = 7
	.Dead, // index 14: dead + 7 neighbors = dead
	.Dead, // index 15: alive + 7 neighbors = dead (overpopulation)

	// neighbor_count = 8
	.Dead, // index 16: dead + 8 neighbors = dead
	.Dead, // index 17: alive + 8 neighbors = dead (overpopulation)

	// Padding (unused)
	.Dead,
	.Dead,
	.Dead,
	.Dead,
	.Dead,
	.Dead,
	.Dead,
	.Dead,
	.Dead,
	.Dead,
	.Dead,
	.Dead,
	.Dead,
	.Dead,
}

rules_get_next :: #force_inline proc(
	neighbor_count: int,
	cell_state: CellState,
) -> CellState #no_bounds_check {
	rule_index := rules_encode(neighbor_count, cell_state)
	return RULES_LUT[rule_index]
}

@(private)
rules_encode :: #force_inline proc(
	neighbor_count: int,
	cell_state: CellState,
) -> int #no_bounds_check {
	return (neighbor_count * 2) + int(cell_state)
}
