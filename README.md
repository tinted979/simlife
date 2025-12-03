# SimLife

SimLife is a high-performance [Conway's Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life) simulator written in the [Odin programming language](https://odin-lang.org/). It features a graphical interactive mode powered by Raylib and a headless benchmark mode for performance testing.

## Features

- **Look-Up Table**: Pre-calculated LUT for all possible Cell States.
- **Ghost Cells**: Padded memory to safely skip bound checks and handle wrap-around logic.

## Prerequisites

- [Odin Compiler](https://odin-lang.org/docs/install/) (latest version)

## Building and Running

To run the project, use the Odin compiler. It is recommended to use `-o:speed` for release builds to ensure smooth performance, especially with large grids.

### Interactive Mode

Run the simulation in a window:

```bash
odin run src/ -o:speed
```

### Benchmark Mode

Run a headless benchmark to measure simulation steps per second:

```bash
odin run src/ -o:speed -- -bench -gen=5000
```

*Note: The `--` separator is required to pass flags to the program instead of the compiler.*

## Configuration

You can customize the simulation using the following command-line arguments:

| Flag       | Default | Description                                      |
| :--------- | :------ | :----------------------------------------------- |
| `-width`   | 600     | Window width in pixels                           |
| `-height`  | 600     | Window height in pixels                          |
| `-grid-w`  | 10000   | Simulation grid width (cells)                    |
| `-grid-h`  | 10000   | Simulation grid height (cells)                   |
| `-gen`     | 1       | Number of generations to simulate in benchmark   |
| `-bench`   | false   | Enable benchmark mode (disables window)          |

## Project Structure

- `src/main.odin`: Entry point, CLI argument parsing, and main loop management.
- `src/simulator/core.odin`: Core simulation logic (state management, step function).
- `src/config/settings.odin`: Default configuration constants.

## License

MIT License
