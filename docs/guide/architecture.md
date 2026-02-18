# Architecture

ZMouse is built with a modular architecture in Zig for Windows.

## Project Structure

```
zmouse/
├── build.zig           # Zig build configuration
├── src/
│   ├── root.zig        # Public API entry point (library)
│   ├── main.zig        # CLI entry point and REPL loop
│   ├── errors.zig      # Domain-specific error types
│   ├── mouse.zig       # Mouse and keyboard input operations
│   ├── recorder.zig    # Input event recording with hooks
│   ├── http_server.zig # HTTP REST API server
│   ├── screenshot.zig  # Screen capture using GDI
│   ├── json_io.zig     # JSON serialization for events
│   ├── commands.zig    # CLI command parsing and dispatch
│   ├── coordinates.zig # Pixel to normalized coordinate conversion
│   └── win32.zig       # Win32 API bindings
├── docs/               # VitePress documentation
└── README.md
```

## Module Responsibilities

| Module | Purpose |
|--------|---------|
| `root.zig` | Public API exports, type re-exports for library users |
| `main.zig` | CLI REPL loop, argument parsing, stdin reading |
| `errors.zig` | Domain error types: `InputError`, `RecorderError`, `ServerError`, etc. |
| `mouse.zig` | `moveMouse()`, `leftClick()`, `sendKey()`, `ScreenDimensions` |
| `recorder.zig` | `Recorder` struct, `Event`, `EventType`, hook thread |
| `http_server.zig` | `Server` struct, HTTP routing, request handling |
| `json_io.zig` | `saveEvents()`, `loadEvents()` - JSON file I/O |
| `commands.zig` | `runCommand()` - parse and dispatch CLI commands |
| `coordinates.zig` | `toAbsoluteX/Y()` - pixel to 0-65535 conversion |
| `screenshot.zig` | `Screenshot` struct, `captureScreen()`, BMP encoding |
| `win32.zig` | Win32 constants, structs, extern function declarations |

## Key Design Patterns

### State Encapsulation

All state is encapsulated in structs instead of global variables:

```zig
// Recorder with encapsulated state
pub const Recorder = struct {
    events: std.ArrayListUnmanaged(Event),
    allocator: std.mem.Allocator,
    recording: bool,
    start_time: u64,
    mouse_hook: ?win32.HHOOK,
    keyboard_hook: ?win32.HHOOK,
    hook_thread: ?win32.HANDLE,
    stop_thread: bool,

    pub fn init(allocator: std.mem.Allocator) Recorder { ... }
    pub fn deinit(self: *Recorder) void { ... }
    pub fn startRecording(self: *Recorder) RecorderError!void { ... }
    pub fn stopRecording(self: *Recorder) void { ... }
};
```

### Explicit Error Handling

Functions return domain-specific errors instead of silent failure:

```zig
pub const InputError = error{
    SendInputFailed,
    InvalidCoordinates,
    ScreenDimensionsInvalid,
};

pub fn moveMouse(x: i32, y: i32, screen: ScreenDimensions) InputError!void {
    if (!screen.isValid()) return error.ScreenDimensionsInvalid;
    // ...
    if (sent == 0) return error.SendInputFailed;
}
```

### Allocator Passing

Allocators are passed explicitly, not stored globally:

```zig
var recorder = Recorder.init(allocator);
defer recorder.deinit();

try zmouse.storage.saveEvents(events, "file.json", allocator);
```

## Win32 API Layer

### Bindings (`win32.zig`)

- **Constants**: `MOUSEEVENTF_*`, `WH_MOUSE_LL`, socket constants, GDI constants
- **Structs**: `INPUT`, `MOUSEINPUT`, `KEYBDINPUT`, `MSLLHOOKSTRUCT`, `SOCKADDR_IN`, `BITMAPINFO`
- **Functions**: `SendInput`, `SetWindowsHookExW`, `GetSystemMetrics`, socket functions, GDI functions

### Compile-Time Validation

```zig
comptime {
    const expected: usize = if (@sizeOf(usize) == 8) 40 else 28;
    if (@sizeOf(INPUT) != expected)
        @compileError("INPUT struct size does not match Win32 ABI");
}
```

## Recording Architecture

```
┌─────────────────┐
│   Main Thread   │
│   (REPL loop)   │
└────────┬────────┘
         │ startRecording()
         ▼
┌─────────────────┐
│  Hook Thread    │
│  (message pump) │
│                 │
│ WH_MOUSE_LL     │◄──── System mouse events
│ WH_KEYBOARD_LL  │◄──── System keyboard events
└────────┬────────┘
         │ appendEvent()
         ▼
┌─────────────────┐
│  Event Buffer   │
│ (ArrayListUnmanaged)
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
│ Server.poll │────►│ routeRequest │
│ (non-block) │     │              │
└─────────────┘     └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌─────────┐  ┌──────────┐  ┌────────────┐
        │ mouse   │  │ recorder │  │ screenshot │
        │ input   │  │          │  │            │
        └─────────┘  └──────────┘  └────────────┘
```

The HTTP server uses non-blocking sockets and is polled during the REPL loop, allowing both CLI and HTTP to work simultaneously.

## Build System

```bash
zig build              # Debug build
zig build -Doptimize=ReleaseSafe  # Release build
zig build run          # Build and run
zig build run -- --http  # Run with HTTP server
zig build test         # Run all tests
```

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| State encapsulation | Enables multiple recorders/servers, easier testing |
| Explicit errors | Clear failure modes, no silent failures |
| Separate hook thread | Hooks require message pump in same thread |
| Manual JSON parsing | No external dependencies, simple format |
| BMP for screenshots | Simple format, no compression library needed |
| Non-blocking HTTP | Allows CLI and HTTP to coexist |
| Win32 sockets | No dependency on Zig's evolving std.http |
| Library entry point | Enables use as a dependency in other projects |

## Testing

Tests are in the source files using `test` blocks:

```zig
// coordinates.zig
test "toAbsoluteX maps 0 to 0" {
    try std.testing.expectEqual(@as(i32, 0), toAbsoluteX(0, 1920));
}

// recorder.zig
test "Recorder init/deinit" {
    var rec = Recorder.init(std.testing.allocator);
    defer rec.deinit();
    try std.testing.expectEqual(false, rec.isRecording());
}
```

Run with `zig build test`.
