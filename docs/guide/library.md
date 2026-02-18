# Library Usage

ZMouse can be imported as a library in other Zig projects, providing full access to input control, recording, and screenshot functionality.

## Adding ZMouse to Your Project

### Option 1: Local Path

In your `build.zig`:

```zig
const zmouse_dep = b.dependency("zmouse", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zmouse", zmouse_dep.module("zmouse"));
```

In your `build.zig.zon`:

```zig
.dependencies = .{
    .zmouse = .{
        .path = "../zmouse",  // Adjust path as needed
    },
},
```

### Option 2: Copy Source Files

Copy the `src/` directory to your project and import directly:

```zig
const zmouse = @import("path/to/zmouse/src/root.zig");
```

## Basic Usage

```zig
const std = @import("std");
const zmouse = @import("zmouse");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get screen dimensions (required for mouse operations)
    const screen = try zmouse.input.getScreenDimensions();
    std.debug.print("Screen: {}x{}\n", .{ screen.width, screen.height });

    // Move mouse to coordinates
    try zmouse.input.moveMouse(500, 300, screen);

    // Click at current position
    zmouse.input.leftClick();
}
```

## API Reference

### Input Module (`zmouse.input`)

#### Types

```zig
/// Screen dimensions for coordinate mapping
pub const ScreenDimensions = struct {
    width: c_int,
    height: c_int,
    
    pub fn isValid(self: ScreenDimensions) bool;
};

/// Mouse position coordinates
pub const MousePosition = struct {
    x: c_long,
    y: c_long,
};
```

#### Functions

```zig
/// Get the primary monitor dimensions
pub fn getScreenDimensions() InputError!ScreenDimensions

/// Get current mouse cursor position
pub fn getPosition() ?MousePosition

/// Move mouse to absolute pixel coordinates
pub fn moveMouse(x: i32, y: i32, screen: ScreenDimensions) InputError!void

/// Click operations
pub fn leftClick() void
pub fn rightClick() void
pub fn doubleClick() void

/// Scroll the mouse wheel (positive = up, negative = down)
pub fn scrollWheel(amount: i32) void
pub fn scrollUp(amount: i32) void
pub fn scrollDown(amount: i32) void

/// Keyboard input
pub fn sendKey(vk: u16, key_up: bool) void
pub fn pressKey(vk: u16) void
pub fn keyDown(vk: u16) void
pub fn keyUp(vk: u16) void
```

### Recorder Module (`zmouse.Recorder`)

```zig
const Recorder = zmouse.Recorder;

/// Initialize a new recorder
var recorder = Recorder.init(allocator);
defer recorder.deinit();

/// Start recording input events
try recorder.startRecording();

/// Stop recording
recorder.stopRecording();

/// Check if currently recording
const is_recording = recorder.isRecording();

/// Get recorded events
const events = recorder.getEvents();

/// Get event count
const count = recorder.getEventCount();

/// Clear all events
recorder.clearEvents();

/// Load events from slice
try recorder.setEvents(events_slice);
```

### Event Types

```zig
pub const EventType = enum {
    move,
    left_down,
    left_up,
    right_down,
    right_up,
    wheel,
    key_down,
    key_up,
    
    pub fn toString(self: EventType) []const u8;
    pub fn fromString(s: []const u8) ?EventType;
};

pub const Event = struct {
    timestamp_ms: i64,    // Milliseconds since recording started
    event_type: EventType,
    x: i32,               // Mouse X (0 for keyboard)
    y: i32,               // Mouse Y (0 for keyboard)
    data: i32,            // Wheel delta or virtual key code
};
```

### Storage Module (`zmouse.storage`)

```zig
/// Save events to JSON file
pub fn saveEvents(
    events: []const Event,
    filepath: []const u8,
    allocator: Allocator,
) !void

/// Load events from JSON file
pub fn loadEvents(
    filepath: []const u8,
    allocator: Allocator,
) ![]Event  // Caller must free
```

### Screenshot Module (`zmouse.screenshot`)

```zig
pub const Screenshot = struct {
    width: u32,
    height: u32,
    pixels: []u8,  // BGRA format
    allocator: Allocator,
    
    pub fn deinit(self: *Screenshot) void;
};

/// Capture entire screen
pub fn captureScreen(allocator: Allocator) ?Screenshot

/// Capture rectangular region
pub fn captureRect(allocator: Allocator, x: i32, y: i32, width: u32, height: u32) ?Screenshot

/// Encode as BMP (caller must free)
pub fn encodeBmp(screenshot: *const Screenshot, allocator: Allocator) ?[]u8

/// Encode as base64 (caller must free)
pub fn encodeBase64(data: []const u8, allocator: Allocator) ![]u8
```

### HTTP Server (`zmouse.Server`)

```zig
const Server = zmouse.Server;

var server = Server.init(allocator, screen.width, screen.height, &recorder);
defer server.deinit();

/// Start server on port
try server.start(4000);

/// Poll for connections (call in main loop)
server.poll();

/// Check if running
const running = server.isRunning();

/// Stop server
server.stop();
```

## Error Types

```zig
pub const InputError = error{
    SendInputFailed,
    InvalidCoordinates,
    ScreenDimensionsInvalid,
    GetPositionFailed,
    InvalidKeyCode,
};

pub const RecorderError = error{
    NotInitialized,
    AlreadyRecording,
    HookInstallationFailed,
    ThreadCreationFailed,
    ThreadStopFailed,
    NoEvents,
    OutOfMemory,
};

pub const StorageError = error{
    FileNotFound,
    PermissionDenied,
    InvalidJson,
    PathTooLong,
    FileSizeInvalid,
    CannotOpenFile,
    WriteFailed,
    ReadFailed,
    VersionMismatch,
    OutOfMemory,
};
```

## Complete Example

```zig
const std = @import("std");
const zmouse = @import("zmouse");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize
    const screen = try zmouse.input.getScreenDimensions();
    var recorder = zmouse.Recorder.init(allocator);
    defer recorder.deinit();

    // Record a sequence
    std.debug.print("Recording for 5 seconds...\n", .{});
    try recorder.startRecording();
    
    std.time.sleep(5 * std.time.ns_per_s);
    
    recorder.stopRecording();
    std.debug.print("Recorded {} events\n", .{recorder.getEventCount()});

    // Save to file
    try zmouse.storage.saveEvents(recorder.getEvents(), "macro.json", allocator);

    // Load and replay
    const events = try zmouse.storage.loadEvents("macro.json", allocator);
    defer allocator.free(events);

    try recorder.setEvents(events);
    
    std.debug.print("Replaying...\n", .{});
    // Implement your own playback loop using events
    for (recorder.getEvents()) |event| {
        std.debug.print("Event: {} at ({}, {})\n", .{
            event.event_type,
            event.x,
            event.y,
        });
    }
}
```

## Virtual Key Codes

Common Windows virtual key codes for keyboard input:

| Code | Key |
|------|-----|
| 8 | Backspace |
| 9 | Tab |
| 13 | Enter |
| 16 | Shift |
| 17 | Ctrl |
| 18 | Alt |
| 27 | Escape |
| 32 | Space |
| 37-40 | Arrow keys (Left, Up, Right, Down) |
| 48-57 | 0-9 |
| 65-90 | A-Z |
| 112-123 | F1-F12 |

Full reference: [Microsoft Docs - Virtual Key Codes](https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes)
