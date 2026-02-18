# Installation

## Requirements

- **OS**: Windows 10/11
- **Zig**: 0.16.0-dev or later
- **Build Tool**: Zig build system (no external dependencies)

## Build from Source

```bash
# Clone the repository
git clone https://github.com/shishtpal/zmouse.git
cd zmouse

# Build the project
zig build
```

The executable will be at `zig-out/bin/zmouse.exe`.

## Run

### Interactive CLI Mode

```bash
zig build run
```

This starts an interactive REPL where you can type commands.

### HTTP API Mode

```bash
# Start with HTTP server on default port 4000
zig build run -- --http

# Or specify a custom port
zig build run -- --http 8080
```

### Run Tests

```bash
zig build test
```

## Build Options

```bash
# Debug build (default)
zig build

# Optimized release build
zig build -Doptimize=ReleaseSafe

# Small binary
zig build -Doptimize=ReleaseSmall
```

## Verify Installation

Run the executable and check the help banner:

```
> zig build run

  ZMouse v1.0  (screen 1920 x 1080)
  ─────────────────────────────────────
  m<X>-<Y>   move            c<X>-<Y>   move + left-click
  r<X>-<Y>   move + right    d<X>-<Y>   move + double-click
  sc<N>      scroll up       sd<N>      scroll down
  g          get position    q          quit

  Recording:
  rec           start recording input events
  stop          stop recording
  save <file>   save events to JSON file
  load <file>   load events from JSON file
  play          replay events

>
```

## Using as a Library

ZMouse can be imported as a library in your Zig projects. See the [Library Guide](/guide/library) for details.

## Next Steps

- [Basic Usage](/guide/basic-usage) - Learn the CLI commands
- [HTTP API](/guide/api) - Set up remote control
- [Recording](/guide/recording) - Record and replay input sequences
- [Library Usage](/guide/library) - Use ZMouse in your Zig projects
