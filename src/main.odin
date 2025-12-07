package main

import "base:runtime"
import "core:flags"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:time"

import dbg "debug"
import sim "simulator"
import rl "vendor:raylib"

main :: proc() {
	debug_state := dbg.init()
	defer dbg.destroy(debug_state)

	args := parse_args_or_exit()
	if args.benchmark {
		run_benchmark(args)
		return
	} else {
		run_interactive(args)
		return
	}
}

parse_args_or_exit :: proc() -> Args {
	args, error := args_parse()
	switch e in error {
	case None:
		return args
	case Invalid_Generation_Count:
		fmt.printfln(
			"Invalid generation count - value: %d (min: %d, max: %d)",
			e.value,
			e.min_value,
			e.max_value,
		)
		os.exit(1)
	case Invalid_Generation_Interval:
		fmt.printfln(
			"Invalid generation interval - value: %d (min: %d, max: %d)",
			e.value,
			e.min_value,
			e.max_value,
		)
		os.exit(1)
	case Invalid_Screen_Width:
		fmt.printfln(
			"Invalid screen width - value: %d (min: %d, max: %d)",
			e.value,
			e.min_value,
			e.max_value,
		)
		os.exit(1)
	case Invalid_Screen_Height:
		fmt.printfln(
			"Invalid screen height - value: %d (min: %d, max: %d)",
			e.value,
			e.min_value,
			e.max_value,
		)
		os.exit(1)
	case Invalid_Grid_Width:
		fmt.printfln(
			"Invalid grid width - value: %d (min: %d, max: %d)",
			e.value,
			e.min_value,
			e.max_value,
		)
		os.exit(1)
	case Invalid_Grid_Height:
		fmt.printfln(
			"Invalid grid height - value: %d (min: %d, max: %d)",
			e.value,
			e.min_value,
			e.max_value,
		)
		os.exit(1)
	case flags.Error:
		fmt.printfln("Flags error: %v", e)
		os.exit(1)
	}
	return args
}

run_benchmark :: proc(args: Args) {
	state := sim.init(args.grid_width, args.grid_height)
	defer sim.destroy(state)

	fmt.printf(
		"Running benchmark for %d generations on a %d x %d grid...\n",
		args.generation_count,
		args.grid_width,
		args.grid_height,
	)

	stopwatch: time.Stopwatch
	time.stopwatch_start(&stopwatch)

	dbg.scoped_event("Benchmark Loop")

	for generation_index in 0 ..< args.generation_count {
		dbg.scoped_event("Step")
		sim.step(state)
	}

	time.stopwatch_stop(&stopwatch)
	elapsed_duration := time.stopwatch_duration(stopwatch)
	elapsed_ms := time.duration_milliseconds(elapsed_duration)

	fmt.printf("Completed in %f ms\n", elapsed_ms)
	fmt.printf("Average per gen: %f ms\n", elapsed_ms / f64(args.generation_count))
}

run_interactive :: proc(args: Args) {
	state := sim.init(args.grid_width, args.grid_height)
	defer sim.destroy(state)

	rl.InitWindow(i32(args.screen_width), i32(args.screen_height), "SimLife")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	pixelBuffer := make([]rl.Color, args.grid_width * args.grid_height)
	defer delete(pixelBuffer)

	baseImage := rl.GenImageColor(i32(args.grid_width), i32(args.grid_height), rl.BLACK)
	texture := rl.LoadTextureFromImage(baseImage)
	rl.UnloadImage(baseImage)
	defer rl.UnloadTexture(texture)

	rl.SetTextureFilter(texture, .POINT)

	sourceRect := rl.Rectangle{0, 0, f32(args.grid_width), f32(args.grid_height)}
	destRect := rl.Rectangle{0, 0, f32(args.screen_width), f32(args.screen_height)}

	stepTimer: f32

	// Performance Tracking
	lastTime := time.now()
	accumulatedTime: f32 = 0
	frameCount := 0
	updateCount := 0

	fpsDisplay := 0
	upsDisplay := 0
	stepTimeDisplay: f64 = 0
	for !rl.WindowShouldClose() {
		dbg.scoped_event("Frame")

		deltaTime := rl.GetFrameTime()
		stepTimer += deltaTime
		accumulatedTime += deltaTime
		frameCount += 1

		if accumulatedTime >= 1.0 {
			fpsDisplay = frameCount
			upsDisplay = updateCount
			frameCount = 0
			updateCount = 0
			accumulatedTime -= 1.0

			// Update window title with stats
			windowTitle := fmt.ctprintf(
				"SimLife - FPS: %d | UPS: %d | Sim Time: %.3f ms",
				fpsDisplay,
				upsDisplay,
				stepTimeDisplay,
			)
			rl.SetWindowTitle(windowTitle)
		}

		if stepTimer >= f32(time.duration_seconds(args.generation_interval * time.Millisecond)) {
			stopwatch: time.Stopwatch
			time.stopwatch_start(&stopwatch)

			{
				dbg.scoped_event("Step Loop")
				for _ in 0 ..< args.generation_count {
					dbg.scoped_event("Step")
					sim.step(state)
				}
			}

			time.stopwatch_stop(&stopwatch)
			stepTimeDisplay = time.duration_milliseconds(time.stopwatch_duration(stopwatch))

			stepTimer = 0
			updateCount += 1
		}

		{
			dbg.scoped_event("Draw Loop")
			pixelIndex := 0
			for y in 1 ..= args.grid_height {
				rowOffset := y * (args.grid_width + 2)
				for x in 1 ..= args.grid_width {
					cellValue := state.current_state.cells[rowOffset + x]
					pixelBuffer[pixelIndex] = cellValue.state == .Alive ? rl.WHITE : rl.BLACK
					pixelIndex += 1
				}
			}
		}

		rl.UpdateTexture(texture, raw_data(pixelBuffer))
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.DrawTexturePro(texture, sourceRect, destRect, rl.Vector2{0, 0}, 0, rl.WHITE)
		rl.EndDrawing()
	}
}
