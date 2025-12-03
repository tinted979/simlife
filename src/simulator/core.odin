package simulator

import "../config"
import "core:math/rand"
import "core:mem"

@(private)
CONWAY_RULES_LUT: [32]u8

Grid :: struct {
	data: []u8,
}

State :: struct {
	curr:                         Grid,
	next:                         Grid,
	generation:                   u64,
	gridWidth, gridHeight:        int,
	paddedWidth, paddedHeight:    int,
}

init :: proc(width: int, height: int) -> (state: State, err: mem.Allocator_Error) {
	init_rules_lut()
	state.gridWidth = width
	state.gridHeight = height
	state.paddedWidth = width + 2
	state.paddedHeight = height + 2
	state.curr.data = make([]u8, state.paddedWidth * state.paddedHeight) or_return
	state.next.data = make([]u8, state.paddedWidth * state.paddedHeight) or_return
	randomize(&state)
	return
}

destroy :: proc(state: ^State) {
	delete(state.curr.data)
	delete(state.next.data)
}

randomize :: proc(state: ^State) {
	for y in 1 ..= state.gridHeight {
		rowOffset := y * state.paddedWidth
		for x in 1 ..= state.gridWidth {
			// ~20% chance of being alive
			state.curr.data[rowOffset + x] = rand.float32() > 0.5 ? 1 : 0
		}
	}
}

step :: proc(state: ^State) #no_bounds_check {
	update_ghost_cells(state)

	// Iterate through rows
	for y in 1 ..= state.gridHeight {
		// Calculate offsets for relative rows
		rowAboveOffset := (y - 1) * state.paddedWidth
		currentRowOffset := y * state.paddedWidth
		rowBelowOffset := (y + 1) * state.paddedWidth

		// Get pointers to the rows
		rowAbove := raw_data(state.curr.data[rowAboveOffset:])
		currentRow := raw_data(state.curr.data[currentRowOffset:])
		rowBelow := raw_data(state.curr.data[rowBelowOffset:])

		// Get pointer to the next row
		nextStateRow := raw_data(state.next.data[currentRowOffset:])

		// Iterate through columns
		for x in 1 ..= state.gridWidth {
			// Calculate sum of neighbors
			neighborCount := 0
			neighborCount += int(rowAbove[x - 1]) + int(rowAbove[x]) + int(rowAbove[x + 1])
			neighborCount += int(currentRow[x - 1]) + int(currentRow[x + 1])
			neighborCount += int(rowBelow[x - 1]) + int(rowBelow[x]) + int(rowBelow[x + 1])

			// Map cell state and sum of neighbors to LUT index
			isAlive := int(currentRow[x])
			lutIndex := (neighborCount * 2) + isAlive
			// Get new state from LUT
			nextStateRow[x] = CONWAY_RULES_LUT[lutIndex]
		}
	}

	// Swap pointers and increment generation
	state.curr, state.next = state.next, state.curr
	state.generation += 1
}

@(private)
update_ghost_cells :: proc(state: ^State) #no_bounds_check {
	grid := &state.curr

	// Iterate through rows
	for y in 1 ..= state.gridHeight {
		rowStart := y * state.paddedWidth
		// Left ghost cell gets rightmost real column
		grid.data[rowStart] = grid.data[rowStart + state.gridWidth]
		// Right ghost cell gets leftmost real column
		grid.data[rowStart + (state.paddedWidth - 1)] = grid.data[rowStart + 1]
	}

	// Copy bottom real row to top ghost row
	topGhostRowDest := &grid.data[0]
	bottomRealRowSrc := &grid.data[state.gridHeight * state.paddedWidth]
	mem.copy(topGhostRowDest, bottomRealRowSrc, state.paddedWidth)

	// Copy top real row to bottom ghost row
	bottomGhostRowDest := &grid.data[(state.paddedHeight - 1) * state.paddedWidth]
	topRealRowSrc := &grid.data[1 * state.paddedWidth]
	mem.copy(bottomGhostRowDest, topRealRowSrc, state.paddedWidth)
}

@(private)
init_rules_lut :: proc() {
	for neighborCount in 0 ..= 8 {
		for cellState in 0 ..= 1 {
			willBeAlive := false
			if cellState == 1 {
				if neighborCount == 2 || neighborCount == 3 do willBeAlive = true
			} else {
				if neighborCount == 3 do willBeAlive = true
			}
			lutIndex := (neighborCount * 2) + cellState
			CONWAY_RULES_LUT[lutIndex] = willBeAlive ? 1 : 0
		}
	}
}
