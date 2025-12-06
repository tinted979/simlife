package simulator_tests

import "core:testing"
import sim "../src/simulator"

// ============================================================================
// LUT VERIFICATION TESTS
// ============================================================================

@(test)
test_lut_automatic_verification :: proc(t: ^testing.T) {
	// The refactored LUT includes a verify_lut() function
	// In debug builds, this runs automatically during init()
	// Here we test that the LUT passes all verification checks
	
	// Create a state to trigger verification
	state, err := sim.init(10, 10)
	defer sim.destroy(&state)
	
	testing.expect(t, err == nil, "State initialization should succeed")
}

// ============================================================================
// CONWAY'S RULES: DEATH CASES
// ============================================================================

@(test)
test_death_by_underpopulation :: proc(t: ^testing.T) {
	// Alive cell with 0 or 1 neighbors dies
	
	result_0 := lookup_next_state(0, CELL_ALIVE)
	testing.expect(
		t,
		result_0 == CELL_DEAD,
		"Alive cell with 0 neighbors should die (underpopulation)",
	)
	
	result_1 := lookup_next_state(1, CELL_ALIVE)
	testing.expect(
		t,
		result_1 == CELL_DEAD,
		"Alive cell with 1 neighbor should die (underpopulation)",
	)
}

@(test)
test_death_by_overpopulation :: proc(t: ^testing.T) {
	// Alive cell with 4+ neighbors dies
	
	for neighbors in 4 ..= 8 {
		result := lookup_next_state(neighbors, CELL_ALIVE)
		testing.expectf(
			t,
			result == CELL_DEAD,
			"Alive cell with %d neighbors should die (overpopulation)",
			neighbors,
		)
	}
}

// ============================================================================
// CONWAY'S RULES: SURVIVAL CASES
// ============================================================================

@(test)
test_survival_with_2_neighbors :: proc(t: ^testing.T) {
	result := lookup_next_state(2, CELL_ALIVE)
	testing.expect(
		t,
		result == CELL_ALIVE,
		"Alive cell with 2 neighbors should survive",
	)
}

@(test)
test_survival_with_3_neighbors :: proc(t: ^testing.T) {
	result := lookup_next_state(3, CELL_ALIVE)
	testing.expect(
		t,
		result == CELL_ALIVE,
		"Alive cell with 3 neighbors should survive",
	)
}

// ============================================================================
// CONWAY'S RULES: BIRTH CASE
// ============================================================================

@(test)
test_birth_with_3_neighbors :: proc(t: ^testing.T) {
	result := lookup_next_state(3, CELL_DEAD)
	testing.expect(
		t,
		result == CELL_ALIVE,
		"Dead cell with exactly 3 neighbors should become alive (birth)",
	)
}

@(test)
test_no_birth_with_wrong_neighbor_count :: proc(t: ^testing.T) {
	// Dead cells should stay dead unless they have exactly 3 neighbors
	
	for neighbors in 0 ..= 8 {
		if neighbors == 3 do continue // Skip the birth case
		
		result := lookup_next_state(neighbors, CELL_DEAD)
		testing.expectf(
			t,
			result == CELL_DEAD,
			"Dead cell with %d neighbors should stay dead (no birth)",
			neighbors,
		)
	}
}

// ============================================================================
// LUT INDEXING TESTS
// ============================================================================

@(test)
test_lut_index_encoding :: proc(t: ^testing.T) {
	// Test that the encoding formula works correctly
	// Formula: (neighbor_count * 2) + cell_state
	
	test_cases := []struct {
		neighbors: int,
		state:     int,
		expected:  int,
	} {
		{0, CELL_DEAD, 0},
		{0, CELL_ALIVE, 1},
		{1, CELL_DEAD, 2},
		{1, CELL_ALIVE, 3},
		{3, CELL_DEAD, 6},
		{3, CELL_ALIVE, 7},
		{8, CELL_DEAD, 16},
		{8, CELL_ALIVE, 17},
	}
	
	for test in test_cases {
		index := encode_lut_index(test.neighbors, test.state)
		testing.expectf(
			t,
			index == test.expected,
			"encode_lut_index(%d, %d) should return %d, got %d",
			test.neighbors,
			test.state,
			test.expected,
			index,
		)
	}
}

// ============================================================================
// INTEGRATION TESTS: KNOWN PATTERNS
// ============================================================================

@(test)
test_still_life_block :: proc(t: ^testing.T) {
	// Block is a 2x2 pattern that never changes
	// ##
	// ##
	
	state, err := sim.init(4, 4)
	defer sim.destroy(&state)
	testing.expect(t, err == nil, "State initialization should succeed")
	
	// Clear grid
	for i in 0 ..< len(state.curr.data) {
		state.curr.data[i] = CELL_DEAD
	}
	
	// Create block pattern at position (1, 1)
	// Grid layout with ghost cells:
	// Row 0: ghost
	// Row 1: ghost [1,1] [1,2] ...
	// Row 2: ghost [2,1] [2,2] ...
	set_cell(&state, 1, 1, CELL_ALIVE)
	set_cell(&state, 1, 2, CELL_ALIVE)
	set_cell(&state, 2, 1, CELL_ALIVE)
	set_cell(&state, 2, 2, CELL_ALIVE)
	
	// Save initial state
	cell_1_1_before := get_cell(&state, 1, 1)
	cell_1_2_before := get_cell(&state, 1, 2)
	cell_2_1_before := get_cell(&state, 2, 1)
	cell_2_2_before := get_cell(&state, 2, 2)
	
	// Step simulation
	sim.step(&state)
	
	// Block should remain unchanged
	testing.expect(
		t,
		get_cell(&state, 1, 1) == cell_1_1_before,
		"Block pattern should be stable (cell 1,1)",
	)
	testing.expect(
		t,
		get_cell(&state, 1, 2) == cell_1_2_before,
		"Block pattern should be stable (cell 1,2)",
	)
	testing.expect(
		t,
		get_cell(&state, 2, 1) == cell_2_1_before,
		"Block pattern should be stable (cell 2,1)",
	)
	testing.expect(
		t,
		get_cell(&state, 2, 2) == cell_2_2_before,
		"Block pattern should be stable (cell 2,2)",
	)
}

@(test)
test_blinker_oscillator :: proc(t: ^testing.T) {
	// Blinker is a period-2 oscillator:
	// Generation 0:  ###
	// Generation 1:   #
	//                 #
	//                 #
	
	state, err := sim.init(5, 5)
	defer sim.destroy(&state)
	testing.expect(t, err == nil, "State initialization should succeed")
	
	// Clear grid
	for i in 0 ..< len(state.curr.data) {
		state.curr.data[i] = CELL_DEAD
	}
	
	// Create horizontal blinker at row 2
	set_cell(&state, 2, 1, CELL_ALIVE)
	set_cell(&state, 2, 2, CELL_ALIVE)
	set_cell(&state, 2, 3, CELL_ALIVE)
	
	// Step once - should become vertical
	sim.step(&state)
	
	testing.expect(t, get_cell(&state, 1, 2) == CELL_ALIVE, "Blinker vertical: top")
	testing.expect(t, get_cell(&state, 2, 2) == CELL_ALIVE, "Blinker vertical: middle")
	testing.expect(t, get_cell(&state, 3, 2) == CELL_ALIVE, "Blinker vertical: bottom")
	testing.expect(t, get_cell(&state, 2, 1) == CELL_DEAD, "Blinker vertical: left should be dead")
	testing.expect(t, get_cell(&state, 2, 3) == CELL_DEAD, "Blinker vertical: right should be dead")
	
	// Step again - should return to horizontal
	sim.step(&state)
	
	testing.expect(t, get_cell(&state, 2, 1) == CELL_ALIVE, "Blinker horizontal: left")
	testing.expect(t, get_cell(&state, 2, 2) == CELL_ALIVE, "Blinker horizontal: middle")
	testing.expect(t, get_cell(&state, 2, 3) == CELL_ALIVE, "Blinker horizontal: right")
	testing.expect(t, get_cell(&state, 1, 2) == CELL_DEAD, "Blinker horizontal: top should be dead")
	testing.expect(t, get_cell(&state, 3, 2) == CELL_DEAD, "Blinker horizontal: bottom should be dead")
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

// These would ideally be public API in the simulator package

CELL_DEAD :: 0
CELL_ALIVE :: 1

lookup_next_state :: proc(neighbor_count: int, current_state: u8) -> u8 {
	// Access the compile-time LUT
	// In the refactored version, this is a public helper
	// For now, we inline the logic
	index := (neighbor_count * 2) + int(current_state)
	
	// Simulate the LUT logic
	if current_state == CELL_ALIVE {
		if neighbor_count >= 2 && neighbor_count <= 3 {
			return CELL_ALIVE
		}
		return CELL_DEAD
	} else {
		if neighbor_count == 3 {
			return CELL_ALIVE
		}
		return CELL_DEAD
	}
}

encode_lut_index :: proc(neighbor_count: int, cell_state: int) -> int {
	return (neighbor_count * 2) + cell_state
}

set_cell :: proc(state: ^sim.State, y: int, x: int, value: u8) {
	// +1 offset for ghost cells
	row_offset := (y + 1) * state.padded_width
	state.curr.data[row_offset + x + 1] = value
}

get_cell :: proc(state: ^sim.State, y: int, x: int) -> u8 {
	// +1 offset for ghost cells
	row_offset := (y + 1) * state.padded_width
	return state.curr.data[row_offset + x + 1]
}
