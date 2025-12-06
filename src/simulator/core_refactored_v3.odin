package simulator

import "core:fmt"
import "core:math/rand"
import "core:mem"

// ============================================================================
// CELL TYPES
// ============================================================================

// CellState represents the state of a cell in the Game of Life.
CellState :: enum u8 {
	Dead  = 0,
	Alive = 1,
}

// Cell is a type alias for CellState for semantic clarity.
// In this implementation, Cell and CellState are the same.
Cell :: CellState

// Helper constants for common cell states
DEAD :: CellState.Dead
ALIVE :: CellState.Alive

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

// ============================================================================
// LOOKUP TABLE (LUT) IMPLEMENTATION
// ============================================================================

// The LUT maps (neighbor_count, current_state) -> next_state for O(1) rule evaluation.
//
// Indexing formula: index = (neighbor_count * 2) + current_state
//
// Table layout:
//   Index | Neighbors | Current State | Next State | Rule
//   ------|-----------|---------------|------------|-------
//   0     | 0         | Dead          | Dead       | -
//   1     | 0         | Alive         | Dead       | death
//   2     | 1         | Dead          | Dead       | -
//   3     | 1         | Alive         | Dead       | death
//   4     | 2         | Dead          | Dead       | -
//   5     | 2         | Alive         | Alive      | SURVIVE
//   6     | 3         | Dead          | Alive      | BIRTH
//   7     | 3         | Alive         | Alive      | SURVIVE
//   8     | 4         | Dead          | Dead       | -
//   9     | 4         | Alive         | Dead       | death
//   ...
//   16    | 8         | Dead          | Dead       | -
//   17    | 8         | Alive         | Dead       | death
//
// Size: 9 possible neighbor counts (0-8) × 2 states = 18 entries
// Padded to 32 for alignment
LUT_SIZE :: 32

// Conway's rules lookup table - directly initialized as a constant array.
// This is immutable and has zero runtime initialization cost.
@(private)
CONWAY_RULES_LUT :: [LUT_SIZE]CellState{
	// neighbor_count = 0
	.Dead,  // index 0: Dead + 0 neighbors = Dead
	.Dead,  // index 1: Alive + 0 neighbors = Dead (underpopulation)
	
	// neighbor_count = 1
	.Dead,  // index 2: Dead + 1 neighbor = Dead
	.Dead,  // index 3: Alive + 1 neighbor = Dead (underpopulation)
	
	// neighbor_count = 2
	.Dead,  // index 4: Dead + 2 neighbors = Dead
	.Alive, // index 5: Alive + 2 neighbors = Alive (survival)
	
	// neighbor_count = 3
	.Alive, // index 6: Dead + 3 neighbors = Alive (birth)
	.Alive, // index 7: Alive + 3 neighbors = Alive (survival)
	
	// neighbor_count = 4
	.Dead,  // index 8: Dead + 4 neighbors = Dead
	.Dead,  // index 9: Alive + 4 neighbors = Dead (overpopulation)
	
	// neighbor_count = 5
	.Dead,  // index 10: Dead + 5 neighbors = Dead
	.Dead,  // index 11: Alive + 5 neighbors = Dead (overpopulation)
	
	// neighbor_count = 6
	.Dead,  // index 12: Dead + 6 neighbors = Dead
	.Dead,  // index 13: Alive + 6 neighbors = Dead (overpopulation)
	
	// neighbor_count = 7
	.Dead,  // index 14: Dead + 7 neighbors = Dead
	.Dead,  // index 15: Alive + 7 neighbors = Dead (overpopulation)
	
	// neighbor_count = 8
	.Dead,  // index 16: Dead + 8 neighbors = Dead
	.Dead,  // index 17: Alive + 8 neighbors = Dead (overpopulation)
	
	// Padding (unused)
	.Dead, .Dead, .Dead, .Dead, .Dead, .Dead, .Dead, .Dead,
	.Dead, .Dead, .Dead, .Dead, .Dead, .Dead,
}

// encode_lut_index converts neighbor count and cell state to a LUT index.
//
// Formula: (neighbor_count * 2) + cell_state
//
// This encoding packs both inputs into a single index:
// - Even indices (0, 2, 4, ...) represent dead cells
// - Odd indices (1, 3, 5, ...) represent alive cells
@(private) @(inline)
encode_lut_index :: proc(neighbor_count: int, state: CellState) -> int {
	return (neighbor_count * 2) + int(state)
}

// lookup_next_state queries the LUT for the next cell state.
//
// This is the performance-critical hot path, called millions of times per step.
// The inline directive hints to the compiler to inline this for maximum speed.
@(private) @(inline)
lookup_next_state :: proc(neighbor_count: int, current_state: CellState) -> CellState {
	index := encode_lut_index(neighbor_count, current_state)
	return CONWAY_RULES_LUT[index]
}

// apply_conway_rules determines the next cell state based on Conway's rules.
// This is used for verification and can be used to generate LUTs for variants.
//
// Parameters:
//   neighbor_count: Number of alive neighbors (0-8)
//   current_state: Current cell state
//
// Returns: Next state based on Conway's rules
@(private)
apply_conway_rules :: proc(neighbor_count: int, current_state: CellState) -> CellState {
	if current_state == .Alive {
		// Survival rule: 2 or 3 neighbors
		if neighbor_count >= SURVIVAL_MIN_NEIGHBORS &&
		   neighbor_count <= SURVIVAL_MAX_NEIGHBORS {
			return .Alive
		}
		return .Dead // Dies from isolation or overcrowding
	} else {
		// Birth rule: exactly 3 neighbors
		if neighbor_count == BIRTH_NEIGHBOR_COUNT {
			return .Alive
		}
		return .Dead
	}
}

// ============================================================================
// CORE DATA STRUCTURES
// ============================================================================

// Grid represents the 2D cellular automaton grid.
// Data is stored as a flat array with ghost cells for boundary handling.
Grid :: struct {
	data: []Cell,
}

// State represents the complete simulation state.
State :: struct {
	curr:          Grid,
	next:          Grid,
	generation:    u64,
	// Public dimensions (visible grid)
	grid_width:    int,
	grid_height:   int,
	// Internal dimensions (includes ghost cells for wrapping)
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
//   width: Number of cells horizontally (must be > 0)
//   height: Number of cells vertically (must be > 0)
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
	state.curr.data = make([]Cell, state.padded_width * state.padded_height) or_return
	state.next.data = make([]Cell, state.padded_width * state.padded_height) or_return

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
//
// Parameters:
//   state: The simulation state to randomize
//   density: Optional probability of a cell being alive (default 0.5)
randomize :: proc(state: ^State, density: f32 = 0.5) {
	for y in 1 ..= state.grid_height {
		row_offset := y * state.padded_width
		for x in 1 ..= state.grid_width {
			state.curr.data[row_offset + x] = rand.float32() < density ? ALIVE : DEAD
		}
	}
}

// set_cell sets the state of a specific cell in the grid.
//
// Parameters:
//   state: The simulation state
//   x, y: Grid coordinates (0-based, relative to visible grid)
//   cell_state: The new state for the cell
set_cell :: proc(state: ^State, x: int, y: int, cell_state: CellState) {
	// +1 offset for ghost cells
	row_offset := (y + 1) * state.padded_width
	state.curr.data[row_offset + x + 1] = cell_state
}

// get_cell retrieves the state of a specific cell in the grid.
//
// Parameters:
//   state: The simulation state
//   x, y: Grid coordinates (0-based, relative to visible grid)
//
// Returns: The current state of the cell
get_cell :: proc(state: ^State, x: int, y: int) -> CellState {
	// +1 offset for ghost cells
	row_offset := (y + 1) * state.padded_width
	return state.curr.data[row_offset + x + 1]
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
			// Since CellState is enum u8 with Alive=1, we can cast to int
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
		state:       CellState,
		expected:    CellState,
		description: string,
	} {
		// Death by underpopulation
		{0, .Alive, .Dead, "Alive with 0 neighbors dies (underpopulation)"},
		{1, .Alive, .Dead, "Alive with 1 neighbor dies (underpopulation)"},

		// Survival
		{2, .Alive, .Alive, "Alive with 2 neighbors survives"},
		{3, .Alive, .Alive, "Alive with 3 neighbors survives"},

		// Death by overpopulation
		{4, .Alive, .Dead, "Alive with 4 neighbors dies (overpopulation)"},
		{5, .Alive, .Dead, "Alive with 5 neighbors dies (overpopulation)"},
		{8, .Alive, .Dead, "Alive with 8 neighbors dies (overpopulation)"},

		// Birth
		{3, .Dead, .Alive, "Dead with 3 neighbors becomes alive (birth)"},

		// Stay dead
		{0, .Dead, .Dead, "Dead with 0 neighbors stays dead"},
		{1, .Dead, .Dead, "Dead with 1 neighbor stays dead"},
		{2, .Dead, .Dead, "Dead with 2 neighbors stays dead"},
		{4, .Dead, .Dead, "Dead with 4 neighbors stays dead"},
		{8, .Dead, .Dead, "Dead with 8 neighbors stays dead"},
	}

	all_passed := true
	for test in test_cases {
		result := lookup_next_state(test.neighbors, test.state)
		if result != test.expected {
			fmt.eprintfln(
				"LUT TEST FAILED: %s - Expected %v, got %v (neighbors=%d, state=%v)",
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
		for cell_state in CellState {
			index := encode_lut_index(neighbor_count, cell_state)
			next := CONWAY_RULES_LUT[index]

			state_str := cell_state == .Alive ? "Alive" : "Dead "
			next_str := next == .Alive ? "ALIVE" : "Dead "

			rule := ""
			if cell_state == .Dead && next == .Alive {
				rule = "BIRTH"
			} else if cell_state == .Alive && next == .Alive {
				rule = "SURVIVE"
			} else if cell_state == .Alive && next == .Dead {
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

// ============================================================================
// PATTERN LOADING (Bonus Feature)
// ============================================================================

// Pattern represents common Game of Life patterns
Pattern :: enum {
	Block,      // 2x2 still life
	Blinker,    // Period-2 oscillator
	Glider,     // Diagonal spaceship
	Toad,       // Period-2 oscillator
	Beacon,     // Period-2 oscillator
}

// load_pattern loads a known pattern into the grid at the specified position.
//
// Parameters:
//   state: The simulation state
//   pattern: The pattern to load
//   x, y: Top-left position to place the pattern (0-based)
load_pattern :: proc(state: ^State, pattern: Pattern, x: int, y: int) {
	// Clear the area first
	for dy in 0 ..< 5 {
		for dx in 0 ..< 5 {
			if x + dx < state.grid_width && y + dy < state.grid_height {
				set_cell(state, x + dx, y + dy, .Dead)
			}
		}
	}

	switch pattern {
	case .Block:
		// ##
		// ##
		set_cell(state, x, y, .Alive)
		set_cell(state, x + 1, y, .Alive)
		set_cell(state, x, y + 1, .Alive)
		set_cell(state, x + 1, y + 1, .Alive)

	case .Blinker:
		// ###
		set_cell(state, x, y, .Alive)
		set_cell(state, x + 1, y, .Alive)
		set_cell(state, x + 2, y, .Alive)

	case .Glider:
		//  #
		//   #
		// ###
		set_cell(state, x + 1, y, .Alive)
		set_cell(state, x + 2, y + 1, .Alive)
		set_cell(state, x, y + 2, .Alive)
		set_cell(state, x + 1, y + 2, .Alive)
		set_cell(state, x + 2, y + 2, .Alive)

	case .Toad:
		//  ###
		// ###
		set_cell(state, x + 1, y, .Alive)
		set_cell(state, x + 2, y, .Alive)
		set_cell(state, x + 3, y, .Alive)
		set_cell(state, x, y + 1, .Alive)
		set_cell(state, x + 1, y + 1, .Alive)
		set_cell(state, x + 2, y + 1, .Alive)

	case .Beacon:
		// ##
		// ##
		//   ##
		//   ##
		set_cell(state, x, y, .Alive)
		set_cell(state, x + 1, y, .Alive)
		set_cell(state, x, y + 1, .Alive)
		set_cell(state, x + 1, y + 1, .Alive)
		set_cell(state, x + 2, y + 2, .Alive)
		set_cell(state, x + 3, y + 2, .Alive)
		set_cell(state, x + 2, y + 3, .Alive)
		set_cell(state, x + 3, y + 3, .Alive)
	}
}
