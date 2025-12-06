package simulator

import "core:fmt"
import "core:math/rand"
import "core:mem"

// ============================================================================
// CONWAY'S GAME OF LIFE RULES CONFIGURATION
// ============================================================================

// Classic Conway's Game of Life rules (B3/S23):
// - Birth (B3): A dead cell with exactly 3 neighbors becomes alive
// - Survival (S23): A live cell with 2 or 3 neighbors survives
// - Death: All other cases result in a dead cell
BIRTH_NEIGHBOR_COUNT :: 3
SURVIVAL_MIN_NEIGHBORS :: 2
SURVIVAL_MAX_NEIGHBORS :: 3

// Cell state constants for code clarity
CELL_DEAD :: 0
CELL_ALIVE :: 1

// ============================================================================
// LOOKUP TABLE (LUT) IMPLEMENTATION - Direct Initialization
// ============================================================================

// The LUT maps (neighbor_count, current_state) -> next_state for O(1) rule evaluation.
//
// Indexing formula: index = (neighbor_count * 2) + current_state
//
// Table layout:
//   Index | Neighbors | Current State | Next State | Rule
//   ------|-----------|---------------|------------|-------
//   0     | 0         | dead          | dead       | -
//   1     | 0         | alive         | dead       | death
//   2     | 1         | dead          | dead       | -
//   3     | 1         | alive         | dead       | death
//   4     | 2         | dead          | dead       | -
//   5     | 2         | alive         | alive      | SURVIVE
//   6     | 3         | dead          | alive      | BIRTH
//   7     | 3         | alive         | alive      | SURVIVE
//   8     | 4         | dead          | dead       | -
//   9     | 4         | alive         | dead       | death
//   ...
//   16    | 8         | dead          | dead       | -
//   17    | 8         | alive         | dead       | death
//
// Size: 9 possible neighbor counts (0-8) × 2 states = 18 entries
// Padded to 32 for alignment
LUT_SIZE :: 32

// Conway's rules lookup table - directly initialized as a constant array.
// This is immutable and has zero runtime initialization cost.
@(private)
CONWAY_RULES_LUT :: [LUT_SIZE]u8{
	// neighbor_count = 0
	0, // index 0: dead + 0 neighbors = dead
	0, // index 1: alive + 0 neighbors = dead (underpopulation)
	
	// neighbor_count = 1
	0, // index 2: dead + 1 neighbor = dead
	0, // index 3: alive + 1 neighbor = dead (underpopulation)
	
	// neighbor_count = 2
	0, // index 4: dead + 2 neighbors = dead
	1, // index 5: alive + 2 neighbors = ALIVE (survival)
	
	// neighbor_count = 3
	1, // index 6: dead + 3 neighbors = ALIVE (birth)
	1, // index 7: alive + 3 neighbors = ALIVE (survival)
	
	// neighbor_count = 4
	0, // index 8: dead + 4 neighbors = dead
	0, // index 9: alive + 4 neighbors = dead (overpopulation)
	
	// neighbor_count = 5
	0, // index 10: dead + 5 neighbors = dead
	0, // index 11: alive + 5 neighbors = dead (overpopulation)
	
	// neighbor_count = 6
	0, // index 12: dead + 6 neighbors = dead
	0, // index 13: alive + 6 neighbors = dead (overpopulation)
	
	// neighbor_count = 7
	0, // index 14: dead + 7 neighbors = dead
	0, // index 15: alive + 7 neighbors = dead (overpopulation)
	
	// neighbor_count = 8
	0, // index 16: dead + 8 neighbors = dead
	0, // index 17: alive + 8 neighbors = dead (overpopulation)
	
	// Padding (unused)
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
}

// encode_lut_index converts neighbor count and cell state to a LUT index.
//
// Formula: (neighbor_count * 2) + cell_state
//
// This encoding packs both inputs into a single index:
// - Even indices (0, 2, 4, ...) represent dead cells
// - Odd indices (1, 3, 5, ...) represent alive cells
@(private) @(inline)
encode_lut_index :: proc(neighbor_count: int, cell_state: int) -> int {
	return (neighbor_count * 2) + cell_state
}

// lookup_next_state queries the LUT for the next cell state.
//
// This is the performance-critical hot path, called millions of times per step.
// The inline directive hints to the compiler to inline this for maximum speed.
@(private) @(inline)
lookup_next_state :: proc(neighbor_count: int, current_state: u8) -> u8 {
	index := encode_lut_index(neighbor_count, int(current_state))
	return CONWAY_RULES_LUT[index]
}

// ============================================================================
// CORE DATA STRUCTURES
// ============================================================================

Grid :: struct {
	data: []u8,
}

State :: struct {
	curr:          Grid,
	next:          Grid,
	generation:    u64,
	// Public dimensions (visible grid)
	grid_width:    int,
	grid_height:   int,
	// Internal dimensions (includes ghost cells)
	padded_width:  int,
	padded_height: int,
}

// ============================================================================
// PUBLIC API
// ============================================================================

// init creates a new Game of Life simulation state.
//
// The grid is padded with "ghost cells" on all sides to handle wrapping
// and eliminate boundary checks during simulation. The actual grid size
// is (width+2) × (height+2).
//
// Parameters:
//   width: Number of cells horizontally
//   height: Number of cells vertically
//
// Returns:
//   state: Initialized simulation state
//   err: Allocation error if memory cannot be allocated
init :: proc(width: int, height: int) -> (state: State, err: mem.Allocator_Error) {
	state.grid_width = width
	state.grid_height = height
	state.padded_width = width + 2
	state.padded_height = height + 2

	// Allocate both grids (current and next)
	state.curr.data = make([]u8, state.padded_width * state.padded_height) or_return
	state.next.data = make([]u8, state.padded_width * state.padded_height) or_return

	// Initialize with random pattern
	randomize(&state)

	// Verify LUT in debug builds
	when ODIN_DEBUG {
		if !verify_lut() {
			fmt.eprintln("WARNING: Conway's rules LUT verification failed!")
		}
	}

	return
}

// destroy frees all memory associated with the simulation state.
destroy :: proc(state: ^State) {
	delete(state.curr.data)
	delete(state.next.data)
}

// randomize initializes the grid with a random pattern.
//
// Each cell has approximately 50% chance of being alive.
// Only the visible grid area is randomized; ghost cells are updated separately.
randomize :: proc(state: ^State) {
	for y in 1 ..= state.grid_height {
		row_offset := y * state.padded_width
		for x in 1 ..= state.grid_width {
			state.curr.data[row_offset + x] = rand.float32() < 0.5 ? CELL_ALIVE : CELL_DEAD
		}
	}
}

// step advances the simulation by one generation.
//
// Process:
// 1. Update ghost cells to handle wrapping
// 2. For each cell, count alive neighbors
// 3. Look up next state in the LUT based on neighbor count and current state
// 4. Swap current and next grids
//
// Performance: O(width × height)
// Thread safety: Not thread-safe (modifies state)
step :: proc(state: ^State) #no_bounds_check {
	update_ghost_cells(state)

	// Iterate through all visible rows
	for y in 1 ..= state.grid_height {
		// Calculate row offsets for the current cell and its neighbors
		row_above_offset := (y - 1) * state.padded_width
		current_row_offset := y * state.padded_width
		row_below_offset := (y + 1) * state.padded_width

		// Get pointers to rows for faster access
		row_above := raw_data(state.curr.data[row_above_offset:])
		current_row := raw_data(state.curr.data[current_row_offset:])
		row_below := raw_data(state.curr.data[row_below_offset:])
		next_state_row := raw_data(state.next.data[current_row_offset:])

		// Iterate through all visible columns
		for x in 1 ..= state.grid_width {
			// Count alive neighbors in the 3×3 neighborhood
			neighbor_count := 0
			neighbor_count += int(row_above[x - 1]) + int(row_above[x]) + int(row_above[x + 1])
			neighbor_count += int(current_row[x - 1]) + int(current_row[x + 1])
			neighbor_count += int(row_below[x - 1]) + int(row_below[x]) + int(row_below[x + 1])

			// Look up the next state using our constant LUT
			current_state := current_row[x]
			next_state_row[x] = lookup_next_state(neighbor_count, current_state)
		}
	}

	// Swap buffers and increment generation counter
	state.curr, state.next = state.next, state.curr
	state.generation += 1
}

// ============================================================================
// PRIVATE HELPERS
// ============================================================================

// update_ghost_cells synchronizes the ghost cells with the opposite edge.
//
// This implements toroidal (wrapping) topology where:
// - Left edge wraps to right edge
// - Right edge wraps to left edge
// - Top edge wraps to bottom edge
// - Bottom edge wraps to top edge
@(private)
update_ghost_cells :: proc(state: ^State) #no_bounds_check {
	grid := &state.curr

	// Handle left and right ghost columns
	for y in 1 ..= state.grid_height {
		row_start := y * state.padded_width
		// Left ghost cell ← rightmost visible cell
		grid.data[row_start] = grid.data[row_start + state.grid_width]
		// Right ghost cell ← leftmost visible cell
		grid.data[row_start + (state.padded_width - 1)] = grid.data[row_start + 1]
	}

	// Handle top and bottom ghost rows
	// Top ghost row ← bottom visible row
	top_ghost_row_dest := &grid.data[0]
	bottom_real_row_src := &grid.data[state.grid_height * state.padded_width]
	mem.copy(top_ghost_row_dest, bottom_real_row_src, state.padded_width)

	// Bottom ghost row ← top visible row
	bottom_ghost_row_dest := &grid.data[(state.padded_height - 1) * state.padded_width]
	top_real_row_src := &grid.data[1 * state.padded_width]
	mem.copy(bottom_ghost_row_dest, top_real_row_src, state.padded_width)
}

// ============================================================================
// DEBUG AND VERIFICATION
// ============================================================================

// verify_lut runs test cases against the LUT to ensure correctness.
//
// Returns: true if all tests pass, false otherwise
@(private)
verify_lut :: proc() -> bool {
	// Test cases covering all Conway's rules
	test_cases := []struct {
		neighbors:   int,
		state:       int,
		expected:    u8,
		description: string,
	} {
		// Death by underpopulation
		{0, CELL_ALIVE, CELL_DEAD, "Alive with 0 neighbors dies (underpopulation)"},
		{1, CELL_ALIVE, CELL_DEAD, "Alive with 1 neighbor dies (underpopulation)"},

		// Survival
		{2, CELL_ALIVE, CELL_ALIVE, "Alive with 2 neighbors survives"},
		{3, CELL_ALIVE, CELL_ALIVE, "Alive with 3 neighbors survives"},

		// Death by overpopulation
		{4, CELL_ALIVE, CELL_DEAD, "Alive with 4 neighbors dies (overpopulation)"},
		{5, CELL_ALIVE, CELL_DEAD, "Alive with 5 neighbors dies (overpopulation)"},
		{8, CELL_ALIVE, CELL_DEAD, "Alive with 8 neighbors dies (overpopulation)"},

		// Birth
		{3, CELL_DEAD, CELL_ALIVE, "Dead with 3 neighbors becomes alive (birth)"},

		// Stay dead
		{0, CELL_DEAD, CELL_DEAD, "Dead with 0 neighbors stays dead"},
		{1, CELL_DEAD, CELL_DEAD, "Dead with 1 neighbor stays dead"},
		{2, CELL_DEAD, CELL_DEAD, "Dead with 2 neighbors stays dead"},
		{4, CELL_DEAD, CELL_DEAD, "Dead with 4 neighbors stays dead"},
		{8, CELL_DEAD, CELL_DEAD, "Dead with 8 neighbors stays dead"},
	}

	all_passed := true
	for test in test_cases {
		result := lookup_next_state(test.neighbors, u8(test.state))
		if result != test.expected {
			fmt.eprintfln(
				"LUT TEST FAILED: %s - Expected %d, got %d (neighbors=%d, state=%d)",
				test.description,
				test.expected,
				result,
				test.neighbors,
				test.state,
			)
			all_passed = false
		}
	}

	return all_passed
}

// print_lut outputs the entire lookup table in human-readable format.
// Useful for debugging and understanding the LUT structure.
@(private)
print_lut :: proc() {
	fmt.println("\n=== Conway's Game of Life Lookup Table ===")
	fmt.println("Index | Neighbors | State | Next  | Rule")
	fmt.println("------|-----------|-------|-------|------------")

	for neighbor_count in 0 ..= 8 {
		for cell_state in 0 ..= 1 {
			index := encode_lut_index(neighbor_count, cell_state)
			next := CONWAY_RULES_LUT[index]

			state_str := cell_state == CELL_ALIVE ? "alive" : "dead "
			next_str := next == CELL_ALIVE ? "ALIVE" : "dead "

			rule := ""
			if cell_state == CELL_DEAD && next == CELL_ALIVE {
				rule = "BIRTH"
			} else if cell_state == CELL_ALIVE && next == CELL_ALIVE {
				rule = "SURVIVE"
			} else if cell_state == CELL_ALIVE && next == CELL_DEAD {
				rule = "DIE"
			}

			fmt.printf(
				"%5d | %9d | %5s | %5s | %s\n",
				index,
				neighbor_count,
				state_str,
				next_str,
				rule,
			)
		}
	}
	fmt.println()
}
