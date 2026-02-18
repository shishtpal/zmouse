# Installation

## Requirements

- **OS**: Windows 10/11
- **Zig**: 0.16.0-dev or later
- **Build Tool**: Zig build system

## Build from Source

```bash
# Clone the repository
git clone https://github.com/shishtpal/zmouse.git
cd zmouse

# Build the project
zig build
```

The executable will be at `zig-out/bin/mouse_controller.exe`.

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

## Build Options

```bash
# Debug build (default)
zig build

# Optimized release build
zig build -Doptimize=ReleaseSafe

# Cross-compile from Linux/macOS
zig build -Dtarget=x86_64-windows
```

## Verify Installation

Run the executable and check the help banner:

```
> zig build run

  Mouse Controller  (screen 1920 x 1080)
  ─────────────────────────────────────
  m<X>-<Y>   move            c<X>-<Y>   move + left-click
  ...
```

## Next Steps

- [Basic Usage](/guide/basic-usage) - Learn the CLI commands
- [HTTP API](/guide/api) - Set up remote control
- [Recording](/guide/recording) - Record and replay input sequences
