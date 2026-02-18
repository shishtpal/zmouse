# AGENTS.md

Guidelines for AI coding agents working on this project.

## Project Overview

**ZMouse** is a Windows input controller and automation library written in Zig. It provides:
- CLI for mouse/keyboard control
- Input event recording and playback
- HTTP REST API for remote control
- Library API for Zig projects

## Zig Version

This project uses **Zig 0.16.0-dev** with these API patterns:

```zig
// Main function signature
pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc = init.gpa;
}

// Build API
const exe = b.addExecutable(.{
    .name = "zmouse",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }),
});

// Stdin reading
const stdin_file = std.Io.File.stdin();
var reader = std.Io.File.Reader.init(stdin_file, io, &read_buf);

// Args parsing
var arg_iter = try std.process.Args.Iterator.initAllocator(init.minimal.args, alloc);
```

## Project Structure

```
zmouse/
├── build.zig           # Build configuration (test, run steps)
├── src/
│   ├── root.zig        # PUBLIC API - Library entry point
│   ├── main.zig        # CLI entry point
│   ├── errors.zig      # Domain error types (InputError, RecorderError, etc.)
│   ├── mouse.zig       # Input operations (ScreenDimensions, MousePosition)
│   ├── recorder.zig    # Recorder struct with encapsulated state
│   ├── http_server.zig # Server struct with encapsulated state
│   ├── screenshot.zig  # Screenshot struct and capture
│   ├── json_io.zig     # JSON file I/O
│   ├── commands.zig    # CLI command parsing
│   ├── coordinates.zig # Pixel to absolute coordinate conversion
│   └── win32.zig       # Win32 API bindings
├── docs/               # VitePress documentation
├── README.md
└── AGENTS.md           # This file
```

## Architecture (Post-Refactor)

### State Encapsulation

All state is encapsulated in structs (no global state):

```zig
// Recorder
var rec = recorder.Recorder.init(allocator);
defer rec.deinit();
try rec.startRecording();
rec.stopRecording();

// HTTP Server
var server = http_server.Server.init(allocator, screen.width, screen.height, &rec);
defer server.deinit();
try server.start(4000);
```

### Error Handling

Domain-specific error types in `errors.zig`:

```zig
pub const InputError = error{ SendInputFailed, InvalidCoordinates, ... };
pub const RecorderError = error{ NotInitialized, AlreadyRecording, ... };
pub const ServerError = error{ WSAStartupFailed, BindFailed, ... };
pub const StorageError = error{ FileNotFound, InvalidJson, ... };
```

Functions return errors instead of silent failure:

```zig
// Returns error on failure
pub fn moveMouse(x: i32, y: i32, screen: ScreenDimensions) InputError!void
```

### Module Responsibilities

| Module | Purpose |
|--------|---------|
| `root.zig` | Public API exports, type re-exports |
| `main.zig` | CLI REPL loop, args parsing |
| `errors.zig` | All domain error types |
| `mouse.zig` | `moveMouse()`, `leftClick()`, `sendKey()`, `ScreenDimensions` |
| `recorder.zig` | `Recorder` struct, `Event`, `EventType`, hook thread |
| `http_server.zig` | `Server` struct, route handlers, JSON helpers |
| `screenshot.zig` | `Screenshot` struct, `captureScreen()`, BMP encoding |
| `json_io.zig` | `saveEvents()`, `loadEvents()` |
| `commands.zig` | `runCommand()` dispatcher |
| `coordinates.zig` | `toAbsoluteX/Y()` conversion |
| `win32.zig` | Win32 constants, structs, extern functions |

## Build Commands

```powershell
zig build                       # Build to zig-out\bin\zmouse.exe
zig build run                   # Build and run CLI
zig build run -- --http         # Run with HTTP server
zig build run -- --http 8080    # Custom port
zig build test                  # Run all tests
zig build -Doptimize=ReleaseSafe  # Optimized build
```

## Code Conventions

### Naming
- Structs: PascalCase (`Recorder`, `Server`, `ScreenDimensions`)
- Functions: camelCase (`moveMouse`, `startRecording`)
- Constants: SCREAMING_SNAKE_CASE (`MOUSEEVENTF_LEFTDOWN`)
- Local variables: snake_case (`screen_width`, `prev_time`)

### Patterns
- Use `defer` for cleanup: `defer rec.deinit()`
- Use `errdefer` for error cleanup paths
- Pass allocator explicitly, don't store globally
- Return errors instead of panicking
- Use `std.mem.zeroes()` instead of `undefined` for Win32 structs

### Win32 Interop
- All Win32 types in `win32.zig`
- Use `extern struct` for C ABI compatibility
- Use `callconv(.winapi)` for Windows calling convention
- Use `@ptrFromInt` for pointer conversion in hook callbacks

## Key Types

### ScreenDimensions
```zig
pub const ScreenDimensions = struct {
    width: c_int,
    height: c_int,
    pub fn isValid(self: ScreenDimensions) bool { ... }
};
```

### Event
```zig
pub const Event = struct {
    timestamp_ms: i64,
    event_type: EventType,
    x: i32,
    y: i32,
    data: i32,  // wheel delta or virtual key code
};
```

### EventType
```zig
pub const EventType = enum {
    move, left_down, left_up, right_down, right_up, wheel,
    key_down, key_up,
    
    pub fn toString(self: EventType) []const u8 { return @tagName(self); }
    pub fn fromString(s: []const u8) ?EventType { return std.meta.stringToEnum(EventType, s); }
};
```

## Testing

```powershell
# Run all tests
zig build test

# Manual CLI testing
zig build run
> m500-300     # Move mouse
> c100-100     # Click
> g            # Get position
> rec          # Start recording
> stop         # Stop recording
> save test.json
> load test.json
> play
> q

# HTTP API testing
zig build run -- --http
curl http://localhost:4000/api/position
curl -X POST http://localhost:4000/api/move -d '{"x":500,"y":300}'
```

## Recording Architecture

```
┌─────────────────┐
│   Main Thread   │
│   (REPL/HTTP)   │
└────────┬────────┘
         │ startRecording()
         ▼
┌─────────────────┐
│  Hook Thread    │
│  (message pump) │
│                 │
│ WH_MOUSE_LL     │◄── System mouse events
│ WH_KEYBOARD_LL  │◄── System keyboard events
└────────┬────────┘
         │ appendEvent()
         ▼
┌─────────────────┐
│ Recorder.events │
│ (ArrayListUnmanaged)
└─────────────────┘
```

## HTTP Server Architecture

```
Client Request
      │
      ▼
┌─────────────┐
│ Server.poll │ (non-blocking accept)
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│ handleRequest   │
│ routeRequest    │
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌───────┐ ┌────────────┐
│ mouse │ │ recorder   │
│ input │ │ screenshot │
└───────┘ └────────────┘
```

## Platform Notes

- **Windows only** - Uses `user32.dll`, `gdi32.dll`, `ws2_32.dll`, `kernel32.dll`
- Mouse coordinates normalized to 0-65535 for `MOUSEEVENTF_ABSOLUTE`
- Low-level hooks require message pump in same thread
- HTTP server uses Winsock with non-blocking sockets
- Screenshot uses GDI (`GetDC`, `BitBlt`, `GetDIBits`)
