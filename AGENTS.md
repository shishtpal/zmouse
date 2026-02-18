# AGENTS.md

Guidelines for AI coding agents working on this project.

## Project Overview

**zmouse** is a Windows command-line input controller written in Zig. It reads text commands from stdin and executes mouse/keyboard actions using Win32 API via Zig's C interop. Includes recording and playback of input events.

## Zig Version

This project uses **Zig 0.16.0-dev** which has significant breaking changes from 0.13/0.14/0.15:

- `std.io` is replaced by `std.Io`
- `main()` takes `std.process.Init` parameter for I/O access
- `callconv(.winapi)` instead of `WINAPI` constant
- `c_int` is now a primitive type (don't redeclare it)
- Build API uses `root_module` with `b.createModule()` instead of `root_source_file`
- `ArrayList` methods require allocator parameter: `list.append(alloc, item)`
- Use `ArrayListUnmanaged` for global state

## Project Structure

```
zmouse/
├── build.zig           # Zig build configuration
├── src/
│   ├── main.zig        # Entry point and REPL loop
│   ├── win32.zig       # Win32 API bindings
│   ├── coordinates.zig # Pixel to absolute coordinate conversion
│   ├── mouse.zig       # Mouse and keyboard operations
│   ├── commands.zig    # Command parsing and dispatch
│   ├── recorder.zig    # Input event recording with hooks
│   └── json_io.zig     # JSON serialization for events
├── PRD.md              # Product requirements document
├── README.md           # User documentation
└── AGENTS.md           # This file
```

## Module Responsibilities

| Module | Purpose |
|--------|---------|
| `main.zig` | REPL loop, stdin reading, recorder init, screen metrics |
| `win32.zig` | Win32 constants, structs (`INPUT`, `MOUSEINPUT`, `KEYBDINPUT`, hook structs), extern fn declarations |
| `coordinates.zig` | `toAbsoluteX/Y()` - convert pixels to 0-65535 range |
| `mouse.zig` | `moveMouse()`, `leftClick()`, `rightClick()`, `scrollWheel()`, `sendKey()` |
| `commands.zig` | `runCommand()` - parse and dispatch all commands including recording |
| `recorder.zig` | `startRecording()`, `stopRecording()`, hook callbacks, threaded message pump |
| `json_io.zig` | `saveEvents()`, `loadEvents()` - JSON file I/O |

## Build Commands

```powershell
zig build              # Build to zig-out\bin\mouse_controller.exe
zig build run          # Build and run
zig build -Doptimize=ReleaseSafe  # Optimized build
```

## Code Conventions

- Use `std.debug.print` for console output (not the old `std.io.getStdOut()`)
- Use `extern struct` for Win32 structures (C ABI compatibility)
- Keep Win32 bindings isolated in `win32.zig`
- Error handling: return `error.InvalidCommand` for parse failures
- All coordinate commands follow pattern: `<letter><X>-<Y>`
- Use `ArrayListUnmanaged` for global state, pass allocator to methods

## Command Syntax

| Command | Action |
|---------|--------|
| `m<X>-<Y>` | Move mouse to (X, Y) |
| `c<X>-<Y>` | Move and left-click |
| `r<X>-<Y>` | Move and right-click |
| `d<X>-<Y>` | Move and double-click |
| `sc<N>` | Scroll up by N units |
| `sd<N>` | Scroll down by N units |
| `g` | Get mouse position |
| `q` | Quit |
| `rec` | Start recording |
| `stop` | Stop recording |
| `save <file>` | Save events to JSON |
| `load <file>` | Load events from JSON |
| `play` | Replay events |

## Recording Architecture

The recording system uses Win32 low-level hooks:

1. **Hook Thread**: `recorder.zig` spawns a thread that:
   - Installs `WH_MOUSE_LL` and `WH_KEYBOARD_LL` hooks
   - Runs a message pump (`PeekMessageW` loop)
   - Hook callbacks append events to global `ArrayListUnmanaged`

2. **Event Types** (`EventType` enum):
   - Mouse: `move`, `left_down`, `left_up`, `right_down`, `right_up`, `wheel`
   - Keyboard: `key_down`, `key_up`

3. **Event Struct** (`MouseEvent`):
   - `timestamp_ms`: Time since recording started
   - `event_type`: Type of input event
   - `x`, `y`: Mouse coordinates (0 for keyboard)
   - `data`: Wheel delta or virtual key code

4. **Playback**: Iterates events, sleeps for timing, calls `mouse.moveMouse()`, `mouse.sendKey()`, etc.

## Win32 Hooks

```zig
// Hook installation (in separate thread)
mouse_hook = SetWindowsHookExW(WH_MOUSE_LL, mouseHookProc, null, 0);
keyboard_hook = SetWindowsHookExW(WH_KEYBOARD_LL, keyboardHookProc, null, 0);

// Hook callback signature
fn hookProc(nCode: c_int, wParam: usize, lParam: isize) callconv(.winapi) isize
```

## Testing

Manual testing:

1. Run `zig build run`
2. Test basic commands: `m500-300`, `c100-100`, `g`, `sc5`
3. Test recording:
   - `rec` → move mouse, click, type → `stop`
   - `save test.json` → verify JSON file
   - `load test.json` → `play` → verify replay
4. Enter `q` to quit

## Platform Notes

- **Windows only** - uses `user32.dll` and `kernel32.dll` via Zig's C interop
- Coordinates normalized to 0-65535 range for `MOUSEEVENTF_ABSOLUTE`
- `SendInput` used for mouse/keyboard simulation
- Low-level hooks require message pump in same thread
- JSON I/O uses direct Win32 `CreateFileA`/`ReadFile`/`WriteFile` (not std.fs)
