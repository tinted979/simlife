package main

import "config"
import "core:flags"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:prof/spall"
import "core:sync"
import "core:time"
import "simulator"
import rl "vendor:raylib"

spall_ctx: spall.Context
@(thread_local)
spall_buffer: spall.Buffer

Arguments :: struct {
	screen_width:  int `args:"name=width,  usage=Window width in pixels"`,
	screen_height: int `args:"name=height, usage=Window height in pixels"`,
	grid_width:    int `args:"name=grid-w, usage=Simulation grid width"`,
	grid_height:   int `args:"name=grid-h, usage=Simulation grid height"`,
	generations:   int `args:"name=gen,    usage=Number of generations to simulate in benchmark"`,
	benchmark:     bool `args:"name=bench, usage=Run benchmark mode"`,
}

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.println(len(track.allocation_map), "allocations not freed")
				for _, entry in track.allocation_map {
					fmt.println(entry.size, "bytes at", entry.location)
				}
			}

			mem.tracking_allocator_destroy(&track)
		}
	}

	spall_ctx = spall.context_create("game_of_life.spall")
	defer spall.context_destroy(&spall_ctx)

	buffer_backing := make([]u8, spall.BUFFER_DEFAULT_SIZE)
	defer delete(buffer_backing)

	spall_buffer = spall.buffer_create(buffer_backing, u32(sync.current_thread_id()))
	defer spall.buffer_destroy(&spall_ctx, &spall_buffer)

	args := Arguments {
		screen_width  = config.DEFAULT_SCREEN_W,
		screen_height = config.DEFAULT_SCREEN_H,
		grid_width    = config.DEFAULT_GRID_W,
		grid_height   = config.DEFAULT_GRID_H,
		generations   = config.DEFAULT_GENERATIONS,
		benchmark     = false,
	}

	flags.parse_or_exit(&args, os.args)

	state, err := simulator.init(args.grid_width, args.grid_height)
	if err != nil {
		fmt.println("Failed to initialize state:", err)
		return
	}
	defer simulator.destroy(&state)

	if args.benchmark {
		run_benchmark(&state, args.grid_width, args.grid_height, args.generations)
	} else {
		run_interactive(
			&state,
			args.screen_width,
			args.screen_height,
			args.grid_width,
			args.grid_height,
		)
	}
}

run_benchmark :: proc(
	state: ^simulator.State,
	gridWidth: int,
	gridHeight: int,
	generations: int,
) {
	fmt.printf(
		"Running benchmark for %d generations on a %d x %d grid...\n",
		generations,
		gridWidth,
		gridHeight,
	)

	stopwatch: time.Stopwatch
	time.stopwatch_start(&stopwatch)

	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "Benchmark Loop")

	for generationIndex in 0 ..< generations {
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "Step")
		simulator.step(state)
	}

	time.stopwatch_stop(&stopwatch)
	duration := time.stopwatch_duration(stopwatch)
	elapsedMilliseconds := time.duration_milliseconds(duration)

	fmt.printf("Completed in %f ms\n", elapsedMilliseconds)
	fmt.printf("Average per gen: %f ms\n", elapsedMilliseconds / f64(generations))
}

run_interactive :: proc(
	state: ^simulator.State,
	screenWidth: int,
	screenHeight: int,
	gridWidth: int,
	gridHeight: int,
) {
	rl.InitWindow(i32(screenWidth), i32(screenHeight), "SimLife")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	pixelBuffer := make([]rl.Color, gridWidth * gridHeight)
	defer delete(pixelBuffer)

	baseImage := rl.GenImageColor(i32(gridWidth), i32(gridHeight), rl.BLACK)
	texture := rl.LoadTextureFromImage(baseImage)
	rl.UnloadImage(baseImage)
	defer rl.UnloadTexture(texture)

	rl.SetTextureFilter(texture, .POINT)

	sourceRect := rl.Rectangle{0, 0, f32(gridWidth), f32(gridHeight)}
	destRect := rl.Rectangle{0, 0, f32(screenWidth), f32(screenHeight)}

	stepTimer: f32
	stepInterval: f32 = 0.00

	// Performance Tracking
	lastTime := time.now()
	accumulatedTime: f32 = 0
	frameCount := 0
	updateCount := 0

	fpsDisplay := 0
	upsDisplay := 0
	stepTimeDisplay: f64 = 0
	for !rl.WindowShouldClose() {
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "Frame")

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

		if stepTimer >= stepInterval {
			stopwatch: time.Stopwatch
			time.stopwatch_start(&stopwatch)

			simulator.step(state)

			time.stopwatch_stop(&stopwatch)
			stepTimeDisplay = time.duration_milliseconds(time.stopwatch_duration(stopwatch))

			stepTimer = 0
			updateCount += 1
		}

		pixelIndex := 0
		for y in 1 ..= gridHeight {
			rowOffset := y * (gridWidth + 2)
			for x in 1 ..= gridWidth {
				cellValue := state.curr.data[rowOffset + x]
				pixelBuffer[pixelIndex] = cellValue == 1 ? rl.WHITE : rl.BLACK
				pixelIndex += 1
			}
		}

		rl.UpdateTexture(texture, raw_data(pixelBuffer))
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.DrawTexturePro(texture, sourceRect, destRect, rl.Vector2{0, 0}, 0, rl.WHITE)
		rl.EndDrawing()
	}
}
