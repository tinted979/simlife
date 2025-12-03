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
	grid_width: int,
	grid_height: int,
	generations: int,
) {
	fmt.printf(
		"Running benchmark for %d generations on a %d x %d grid...\n",
		generations,
		grid_width,
		grid_height,
	)

	sw: time.Stopwatch
	time.stopwatch_start(&sw)

	spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "Benchmark Loop")

	for i in 0 ..< generations {
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "Step")
		simulator.step(state)
	}

	time.stopwatch_stop(&sw)
	duration := time.stopwatch_duration(sw)
	ms := time.duration_milliseconds(duration)

	fmt.printf("Completed in %f ms\n", ms)
	fmt.printf("Average per gen: %f ms\n", ms / f64(generations))
}

run_interactive :: proc(
	state: ^simulator.State,
	screen_width: int,
	screen_height: int,
	grid_width: int,
	grid_height: int,
) {
	rl.InitWindow(i32(screen_width), i32(screen_height), "SimLife")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	pixel_data := make([]rl.Color, grid_width * grid_height)
	defer delete(pixel_data)

	base_img := rl.GenImageColor(i32(grid_width), i32(grid_height), rl.BLACK)
	texture := rl.LoadTextureFromImage(base_img)
	rl.UnloadImage(base_img)
	defer rl.UnloadTexture(texture)

	rl.SetTextureFilter(texture, .POINT)

	source_rect := rl.Rectangle{0, 0, f32(grid_width), f32(grid_height)}
	dest_rect := rl.Rectangle{0, 0, f32(screen_width), f32(screen_height)}

	timer: f32
	tick_rate: f32 = 0.00

	// Performance Tracking
	last_time := time.now()
	accum_time: f32 = 0
	frame_count := 0
	update_count := 0

	fps_display := 0
	ups_display := 0
	step_time_display: f64 = 0
	for !rl.WindowShouldClose() {
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, "Frame")

		dt := rl.GetFrameTime()
		timer += dt
		accum_time += dt
		frame_count += 1

		if accum_time >= 1.0 {
			fps_display = frame_count
			ups_display = update_count
			frame_count = 0
			update_count = 0
			accum_time -= 1.0

			// Update window title with stats
			title := fmt.ctprintf(
				"SimLife - FPS: %d | UPS: %d | Sim Time: %.3f ms",
				fps_display,
				ups_display,
				step_time_display,
			)
			rl.SetWindowTitle(title)
		}

		if timer >= tick_rate {
			sw: time.Stopwatch
			time.stopwatch_start(&sw)

			simulator.step(state)

			time.stopwatch_stop(&sw)
			step_time_display = time.duration_milliseconds(time.stopwatch_duration(sw))

			timer = 0
			update_count += 1
		}

		p_idx := 0
		for y in 1 ..= grid_height {
			row_offset := y * (grid_width + 2)
			for x in 1 ..= grid_width {
				val := state.curr.data[row_offset + x]
				pixel_data[p_idx] = val == 1 ? rl.WHITE : rl.BLACK
				p_idx += 1
			}
		}

		rl.UpdateTexture(texture, raw_data(pixel_data))
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.DrawTexturePro(texture, source_rect, dest_rect, rl.Vector2{0, 0}, 0, rl.WHITE)
		rl.EndDrawing()
	}
}
