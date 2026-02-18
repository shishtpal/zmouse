# ZMouse

A Windows input controller and automation library written in Zig. Control mouse and keyboard via CLI or HTTP API, record and replay input sequences.

## Features

- **Mouse Control** - Move, click, scroll with pixel-precise coordinates
- **Keyboard Input** - Simulate key presses with virtual key codes
- **Recording & Playback** - Capture input events, save to JSON, replay with timing
- **HTTP REST API** - Remote control from any web app or browser
- **Screenshot Capture** - Screen capture via HTTP endpoint
- **Library Support** - Import as a Zig module in your projects

## Quick Start

```bash
# Build
zig build

# Run interactive CLI
zig build run

# Run with HTTP API (default port 4000)
zig build run -- --http

# Run tests
zig build test
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `m<X>-<Y>` | Move mouse to (X, Y) |
| `c<X>-<Y>` | Move and left-click |
| `r<X>-<Y>` | Move and right-click |
| `d<X>-<Y>` | Move and double-click |
| `sc<N>` | Scroll up by N units |
| `sd<N>` | Scroll down by N units |
| `g` | Get current mouse position |
| `rec` | Start recording input events |
| `stop` | Stop recording |
| `save <file>` | Save events to JSON file |
| `load <file>` | Load events from JSON file |
| `play` | Replay recorded events |
| `q` | Quit |

## HTTP API

Start with `zig build run -- --http [port]`

```bash
# Get mouse position
curl http://localhost:4000/api/position

# Move mouse
curl -X POST http://localhost:4000/api/move -d '{"x":500,"y":300}'

# Click
curl -X POST http://localhost:4000/api/click -d '{"x":100,"y":100,"button":"left"}'

# Screenshot
curl http://localhost:4000/api/screenshot > screen.bmp
```

See [API Documentation](docs/guide/api-endpoints.md) for full endpoint reference.

## Library Usage

ZMouse can be imported as a library in other Zig projects:

```zig
const zmouse = @import("zmouse");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get screen dimensions
    const screen = try zmouse.input.getScreenDimensions();

    // Move and click
    try zmouse.input.moveMouse(500, 300, screen);
    zmouse.input.leftClick();

    // Recording
    var recorder = zmouse.Recorder.init(allocator);
    defer recorder.deinit();

    try recorder.startRecording();
    // ... user performs actions ...
    recorder.stopRecording();

    // Save to file
    try zmouse.storage.saveEvents(recorder.getEvents(), "macro.json", allocator);
}
```

See [Library Guide](docs/guide/library.md) for detailed documentation.

## Project Structure

```
zmouse/
├── build.zig           # Build configuration
├── src/
│   ├── root.zig        # Library entry point (public API)
│   ├── main.zig        # CLI entry point
│   ├── errors.zig      # Domain error types
│   ├── mouse.zig       # Input operations (mouse, keyboard)
│   ├── recorder.zig    # Event recording with Win32 hooks
│   ├── http_server.zig # HTTP REST API server
│   ├── screenshot.zig  # Screen capture using GDI
│   ├── json_io.zig     # JSON serialization
│   ├── commands.zig    # CLI command parsing
│   ├── coordinates.zig # Coordinate conversion
│   └── win32.zig       # Win32 API bindings
├── docs/               # VitePress documentation
└── README.md
```

## Requirements

- **OS**: Windows 10/11
- **Zig**: 0.16.0-dev or later
- **Build**: `zig build` (no external dependencies)

## JSON Format

Recorded events use this format:

```json
{
  "version": 1,
  "events": [
    {"t": 0, "type": "move", "x": 500, "y": 300},
    {"t": 150, "type": "left_down", "x": 500, "y": 300},
    {"t": 200, "type": "left_up", "x": 500, "y": 300},
    {"t": 500, "type": "key_down", "x": 0, "y": 0, "data": 65}
  ]
}
```

## License

MIT
