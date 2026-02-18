# Architecture

ZMouse is built with a modular architecture in Zig for Windows.

## Project Structure

```
zmouse/
├── build.zig           # Zig build configuration
├── src/
│   ├── main.zig        # Entry point, REPL loop, CLI args
│   ├── win32.zig       # Win32 API bindings
│   ├── coordinates.zig # Pixel to normalized coordinate conversion
│   ├── mouse.zig       # Mouse and keyboard operations
│   ├── commands.zig    # CLI command parsing and dispatch
│   ├── recorder.zig    # Input event recording with hooks
│   ├── http_server.zig # HTTP REST API server
│   ├── json_io.zig     # JSON serialization for events
│   └── screenshot.zig  # Screen capture using GDI
├── docs/               # VitePress documentation
└── README.md
```

## Module Responsibilities

| Module | Purpose |
|--------|---------|
| `main.zig` | REPL loop, stdin reading, HTTP server integration |
| `win32.zig` | Win32 constants, structs, extern function declarations |
| `coordinates.zig` | Convert pixels to 0-65535 normalized range |
| `mouse.zig` | `moveMouse()`, `leftClick()`, `sendKey()`, etc. |
| `commands.zig` | Parse and dispatch CLI commands |
| `recorder.zig` | Recording state, hook callbacks, threaded message pump |
| `http_server.zig` | HTTP server, routing, request handling |
| `json_io.zig` | Save/load events to/from JSON files |
| `screenshot.zig` | Screen capture and BMP encoding |

## Key Technologies

### Win32 API

- **SendInput** - Mouse and keyboard simulation
- **SetWindowsHookExW** - Low-level input hooks for recording
- **GetSystemMetrics** - Screen dimensions
- **GDI functions** - Screenshot capture
- **Winsock** - HTTP server

### Zig 0.16 Features

- `std.process.Init` - Main function parameter for I/O
- `std.Io.File.Reader` - Stdin reading
- `std.debug.print` - Console output
- `ArrayListUnmanaged` - Global state storage

## Recording Architecture

```
┌─────────────────┐
│   Main Thread   │
│   (REPL loop)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Hook Thread    │
│  (message pump) │
│                 │
│ WH_MOUSE_LL     │◄──── System mouse events
│ WH_KEYBOARD_LL  │◄──── System keyboard events
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Event Buffer   │
│ (ArrayList)     │
└─────────────────┘
```

The hook thread runs a Windows message pump to receive low-level input events. Events are stored with timestamps for playback.

## HTTP Server Architecture

```
┌─────────────┐
│  HTTP       │
│  Client     │
└──────┬──────┘
       │ HTTP Request
       ▼
┌─────────────┐     ┌──────────────┐
│ HTTP Server │────►│ Route Handler│
│ (poll in    │     │              │
│  REPL loop) │     └──────┬───────┘
└─────────────┘            │
                           ▼
              ┌────────────────────┐
              │ mouse.zig /        │
              │ recorder.zig /     │
              │ screenshot.zig     │
              └────────────────────┘
```

The HTTP server uses non-blocking sockets and is polled during the REPL loop, allowing both CLI and HTTP to work simultaneously.

## Build System

```bash
zig build              # Debug build
zig build -Doptimize=ReleaseSafe  # Release build
zig build run          # Build and run
zig build run -- --http  # Run with HTTP server
```

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Separate hook thread | Hooks require a message pump in the same thread |
| Manual JSON parsing | No external dependencies, simple format |
| BMP for screenshots | Simple format, no compression library needed |
| Non-blocking HTTP | Allows CLI and HTTP to coexist |
| Win32 sockets | No dependency on Zig's evolving std.http |
