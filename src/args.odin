package main

import "core:flags"
import "core:os"
import "core:time"

DEFAULT_BENCHMARK :: false

MIN_GENERATION_COUNT :: 1
MAX_GENERATION_COUNT :: 1_000_000
DEFAULT_GENERATION_COUNT :: 1

MIN_GENERATION_INTERVAL :: 0 * time.Millisecond
MAX_GENERATION_INTERVAL :: 1 * time.Minute
DEFAULT_GENERATION_INTERVAL :: 0

MIN_SCREEN_WIDTH :: 1
MAX_SCREEN_WIDTH :: 7680
DEFAULT_SCREEN_WIDTH :: 800

MIN_SCREEN_HEIGHT :: 1
MAX_SCREEN_HEIGHT :: 4320
DEFAULT_SCREEN_HEIGHT :: 600

MIN_GRID_WIDTH :: 1
MAX_GRID_WIDTH :: 1_000_000
DEFAULT_GRID_WIDTH :: 1000

MIN_GRID_HEIGHT :: 1
MAX_GRID_HEIGHT :: 1_000_000
DEFAULT_GRID_HEIGHT :: 1000

Args :: struct {
	benchmark:           bool `args:"name=bench" usage:"Run benchmark - Default: false"`,
	generation_count:    int `args:"name=gen-count" usage:"Generation count - Default: 1"`,
	generation_interval: time.Duration `args:"name=gen-interval" usage:"Interval between generations in milliseconds - Default: 0ms"`,
	screen_width:        int `args:"name=screen-width" usage:"Window width in pixels - Default: 800"`,
	screen_height:       int `args:"name=screen-height" usage:"Window height in pixels - Default: 600"`,
	grid_width:          int `args:"name=grid-width" usage:"Simulation grid width - Default: 1,000"`,
	grid_height:         int `args:"name=grid-height" usage:"Simulation grid height - Default: 1,000"`,
}

Args_Error :: union {
	None,
	flags.Error,
	Invalid_Grid_Width,
	Invalid_Grid_Height,
	Invalid_Generation_Count,
	Invalid_Generation_Interval,
	Invalid_Screen_Width,
	Invalid_Screen_Height,
}

None :: struct {}

Invalid_Grid_Width :: struct {
	value:     int,
	min_value: int,
	max_value: int,
}

Invalid_Grid_Height :: struct {
	value:     int,
	min_value: int,
	max_value: int,
}

Invalid_Generation_Count :: struct {
	value:     int,
	min_value: int,
	max_value: int,
}

Invalid_Generation_Interval :: struct {
	value:     time.Duration,
	min_value: time.Duration,
	max_value: time.Duration,
}

Invalid_Screen_Width :: struct {
	value:     int,
	min_value: int,
	max_value: int,
}

Invalid_Screen_Height :: struct {
	value:     int,
	min_value: int,
	max_value: int,
}

args_parse :: proc() -> (args: Args, error: Args_Error) {
	args = args_default()
	flags.parse(&args, os.args[1:]) or_return
	return args, args_validate(&args)
}

@(private)
args_default :: proc() -> Args {
	return Args {
		benchmark = DEFAULT_BENCHMARK,
		generation_count = DEFAULT_GENERATION_COUNT,
		generation_interval = DEFAULT_GENERATION_INTERVAL,
		screen_width = DEFAULT_SCREEN_WIDTH,
		screen_height = DEFAULT_SCREEN_HEIGHT,
		grid_width = DEFAULT_GRID_WIDTH,
		grid_height = DEFAULT_GRID_HEIGHT,
	}
}

@(private)
args_validate :: proc(args: ^Args) -> Args_Error {
	if args.generation_count < MIN_GENERATION_COUNT ||
	   args.generation_count > MAX_GENERATION_COUNT {
		return Invalid_Generation_Count {
			value = args.generation_count,
			min_value = MIN_GENERATION_COUNT,
			max_value = MAX_GENERATION_COUNT,
		}
	}

	if args.generation_interval < MIN_GENERATION_INTERVAL ||
	   args.generation_interval > MAX_GENERATION_INTERVAL {
		return Invalid_Generation_Interval {
			value = args.generation_interval,
			min_value = MIN_GENERATION_INTERVAL,
			max_value = MAX_GENERATION_INTERVAL,
		}
	}

	if args.screen_width < MIN_SCREEN_WIDTH || args.screen_width > MAX_SCREEN_WIDTH {
		return Invalid_Screen_Width {
			value = args.screen_width,
			min_value = MIN_SCREEN_WIDTH,
			max_value = MAX_SCREEN_WIDTH,
		}
	}

	if args.screen_height < MIN_SCREEN_HEIGHT || args.screen_height > MAX_SCREEN_HEIGHT {
		return Invalid_Screen_Height {
			value = args.screen_height,
			min_value = MIN_SCREEN_HEIGHT,
			max_value = MAX_SCREEN_HEIGHT,
		}
	}

	if args.grid_width < MIN_GRID_WIDTH || args.grid_width > MAX_GRID_WIDTH {
		return Invalid_Grid_Width {
			value = args.grid_width,
			min_value = MIN_GRID_WIDTH,
			max_value = MAX_GRID_WIDTH,
		}
	}

	if args.grid_height < MIN_GRID_HEIGHT || args.grid_height > MAX_GRID_HEIGHT {
		return Invalid_Grid_Height {
			value = args.grid_height,
			min_value = MIN_GRID_HEIGHT,
			max_value = MAX_GRID_HEIGHT,
		}
	}

	return None{}
}
