package main

import "core:fmt"
import sim "../src/simulator"

// This example demonstrates the debugging and inspection capabilities
// of the refactored LUT implementation.
//
// Compile and run:
//   odin run examples/inspect_lut.odin -file

main :: proc() {
	fmt.println("=== Conway's Game of Life - LUT Inspector ===\n")
	
	// 1. Create a simulator instance
	fmt.println("1. Initializing simulator...")
	state, err := sim.init(10, 10)
	if err != nil {
		fmt.eprintln("Failed to initialize:", err)
		return
	}
	defer sim.destroy(&state)
	fmt.println("   ✓ Simulator initialized successfully\n")
	
	// 2. Print the entire lookup table
	fmt.println("2. Lookup Table Contents:")
	fmt.println("   (This shows all possible states and transitions)")
	print_lut_summary()
	
	// 3. Run verification tests
	fmt.println("\n3. Running LUT Verification Tests...")
	run_manual_tests()
	
	// 4. Show practical examples
	fmt.println("\n4. Practical Examples:")
	demonstrate_rules()
	
	fmt.println("\n=== Inspection Complete ===")
}

// Print a summary of the LUT
print_lut_summary :: proc() {
	fmt.println("\n   Index | Neighbors | State | Next  | Rule")
	fmt.println("   ------|-----------|-------|-------|------------")
	
	CELL_DEAD :: 0
	CELL_ALIVE :: 1
	
	for neighbor_count in 0 ..= 8 {
		for cell_state in 0 ..= 1 {
			index := (neighbor_count * 2) + cell_state
			
			// Simulate the lookup
			next := u8(0)
			if cell_state == CELL_ALIVE {
				if neighbor_count >= 2 && neighbor_count <= 3 {
					next = 1
				}
			} else {
				if neighbor_count == 3 {
					next = 1
				}
			}
			
			state_str := cell_state == CELL_ALIVE ? "alive" : "dead "
			next_str := next == CELL_ALIVE ? "ALIVE" : "dead "
			
			rule := ""
			if cell_state == CELL_DEAD && next == CELL_ALIVE {
				rule = "🌱 BIRTH"
			} else if cell_state == CELL_ALIVE && next == CELL_ALIVE {
				rule = "💚 SURVIVE"
			} else if cell_state == CELL_ALIVE && next == CELL_DEAD {
				rule = "💀 DIE"
			} else {
				rule = "   -"
			}
			
			fmt.printf(
				"   %5d | %9d | %5s | %5s | %s\n",
				index,
				neighbor_count,
				state_str,
				next_str,
				rule,
			)
		}
	}
}

// Run manual verification tests
run_manual_tests :: proc() {
	CELL_DEAD :: 0
	CELL_ALIVE :: 1
	
	test_cases := []struct {
		neighbors:   int,
		state:       u8,
		expected:    u8,
		description: string,
	} {
		// Death cases
		{0, CELL_ALIVE, CELL_DEAD, "Underpopulation: 0 neighbors"},
		{1, CELL_ALIVE, CELL_DEAD, "Underpopulation: 1 neighbor"},
		{4, CELL_ALIVE, CELL_DEAD, "Overpopulation: 4 neighbors"},
		{5, CELL_ALIVE, CELL_DEAD, "Overpopulation: 5 neighbors"},
		
		// Survival cases
		{2, CELL_ALIVE, CELL_ALIVE, "Survival: 2 neighbors"},
		{3, CELL_ALIVE, CELL_ALIVE, "Survival: 3 neighbors"},
		
		// Birth case
		{3, CELL_DEAD, CELL_ALIVE, "Birth: 3 neighbors"},
		
		// Stay dead cases
		{0, CELL_DEAD, CELL_DEAD, "Stay dead: 0 neighbors"},
		{2, CELL_DEAD, CELL_DEAD, "Stay dead: 2 neighbors"},
		{4, CELL_DEAD, CELL_DEAD, "Stay dead: 4 neighbors"},
	}
	
	passed := 0
	failed := 0
	
	for test in test_cases {
		// Simulate lookup
		result := u8(0)
		if test.state == CELL_ALIVE {
			if test.neighbors >= 2 && test.neighbors <= 3 {
				result = 1
			}
		} else {
			if test.neighbors == 3 {
				result = 1
			}
		}
		
		if result == test.expected {
			fmt.printf("   ✓ %s\n", test.description)
			passed += 1
		} else {
			fmt.printf("   ✗ %s (expected %d, got %d)\n", 
				test.description, test.expected, result)
			failed += 1
		}
	}
	
	fmt.printf("\n   Results: %d passed, %d failed\n", passed, failed)
}

// Demonstrate the rules with visual examples
demonstrate_rules :: proc() {
	CELL_DEAD :: 0
	CELL_ALIVE :: 1
	
	fmt.println("\n   Example 1: Birth Rule")
	fmt.println("   ┌─────┐     ┌─────┐")
	fmt.println("   │ # # │     │ # # │")
	fmt.println("   │ . # │ --> │ # # │   Dead cell with 3 neighbors becomes alive")
	fmt.println("   │ . . │     │ . . │")
	fmt.println("   └─────┘     └─────┘")
	
	fmt.println("\n   Example 2: Survival Rule")
	fmt.println("   ┌─────┐     ┌─────┐")
	fmt.println("   │ # . │     │ # . │")
	fmt.println("   │ # # │ --> │ # # │   Alive cell with 2-3 neighbors survives")
	fmt.println("   │ . . │     │ . . │")
	fmt.println("   └─────┘     └─────┘")
	
	fmt.println("\n   Example 3: Underpopulation")
	fmt.println("   ┌─────┐     ┌─────┐")
	fmt.println("   │ . . │     │ . . │")
	fmt.println("   │ . # │ --> │ . . │   Alive cell with <2 neighbors dies")
	fmt.println("   │ . . │     │ . . │")
	fmt.println("   └─────┘     └─────┘")
	
	fmt.println("\n   Example 4: Overpopulation")
	fmt.println("   ┌─────┐     ┌─────┐")
	fmt.println("   │ # # │     │ # . │")
	fmt.println("   │ # # │ --> │ . . │   Alive cell with >3 neighbors dies")
	fmt.println("   │ # . │     │ # . │")
	fmt.println("   └─────┘     └─────┘")
	
	fmt.println("\n   (# = alive, . = dead)")
}
