# Mouse Controller (Modular Zig Implementation)

A command-line input controller for Windows that interprets text commands and executes corresponding mouse and keyboard actions using Win32 API via Zig's C interop. Includes recording and playback functionality.

## Modular Architecture

The implementation is organized into focused modules:

### `src/main.zig`
**Entry point and REPL loop**
- Initializes the console and recorder
- Retrieves screen dimensions via `GetSystemMetrics`
- Implements the read-eval-print loop
- Handles EOF and quit commands

### `src/win32.zig`
**Win32 API bindings**
- Constants: `MOUSEEVENTF_*`, `KEYEVENTF_*`, screen metrics, hook IDs
- Structures: `INPUT`, `MOUSEINPUT`, `KEYBDINPUT`, `MSLLHOOKSTRUCT`, `KBDLLHOOKSTRUCT`
- Extern function declarations: `SendInput`, `SetWindowsHookExW`, `GetSystemMetrics`
- Compile-time ABI validation

### `src/coordinates.zig`
**Coordinate mapping utilities**
- `toAbsoluteX()` – Convert pixel X to 0–65535 normalized range
- `toAbsoluteY()` – Convert pixel Y to 0–65535 normalized range
- Uses 64-bit intermediate arithmetic to prevent overflow

### `src/mouse.zig`
**Low-level input operations**
- `moveMouse()` – Move to absolute pixel coordinates
- `leftClick()`, `rightClick()`, `doubleClick()` – Click operations
- `scrollWheel()` – Scroll up (positive) or down (negative)
- `sendKey()` – Send keyboard key press/release
- Uses Win32 `SendInput` for all operations

### `src/recorder.zig`
**Input event recording**
- `startRecording()` / `stopRecording()` – Control recording state
- Low-level hooks (`WH_MOUSE_LL`, `WH_KEYBOARD_LL`) capture system-wide input
- Runs hook message pump in separate thread
- Stores events with timestamps for accurate playback

### `src/json_io.zig`
**JSON serialization**
- `saveEvents()` – Write recorded events to JSON file
- `loadEvents()` – Read events from JSON file
- Simple manual JSON parsing (no external dependencies)

### `src/commands.zig`
**Command parsing and dispatch**
- `parseXY()` – Parse "X-Y" coordinate pairs
- `execute*()` functions – Handlers for all commands
- `runCommand()` – Main dispatcher that routes commands
- `executePlay()` – Replay recorded events with timing

### `build.zig`
**Zig build configuration**
- Defines build targets
- Configures optimization levels
- Provides `zig build` and `zig build run` commands

## Command Syntax

### Basic Commands

| Command        | Action                                      |
|----------------|---------------------------------------------|
| m\<X\>-\<Y\>   | Move mouse to x=X, y=Y                      |
| c\<X\>-\<Y\>   | Move and left-click                         |
| r\<X\>-\<Y\>   | Move and right-click                        |
| d\<X\>-\<Y\>   | Move and double-click                       |
| sc\<N\>        | Scroll up by N units                        |
| sd\<N\>        | Scroll down by N units                      |
| g              | Get current mouse position                  |
| q              | Quit the program                            |

### Recording Commands

| Command        | Action                                      |
|----------------|---------------------------------------------|
| rec            | Start recording mouse and keyboard events   |
| stop           | Stop recording                              |
| save \<file\>  | Save recorded events to JSON file           |
| load \<file\>  | Load events from JSON file                  |
| play           | Replay loaded/recorded events               |

## Building

### Using `zig build`
```bash
# Compile with default optimization
zig build

# Compile with specific optimization level
zig build -Doptimize=ReleaseSafe

# Run directly
zig build run
```

### Direct compilation
```bash
zig build-exe src/main.zig -O ReleaseSafe
```

### Cross-compilation
```bash
# From Linux/macOS to Windows
zig build-exe src/main.zig -O ReleaseSafe -target x86_64-windows
```

## Example Usage

### Basic Commands
```
> m500-300
  Mouse moved to (500, 300)

> c120-150
  Mouse moved to (120, 150) and clicked

> g
  Mouse position: (120, 150)

> sc30
  Scrolled up by 30

> q
  Exiting...
```

### Recording and Playback
```
> rec
  Recording started. Use 'stop' to finish.

(move mouse, click, type some keys)

> stop
  Recording stopped. 42 events captured.

> save macro.json
  Saved 42 events to 'macro.json'

> load macro.json
  Loaded 42 events from 'macro.json'

> play
  Playing 42 events...
  Playback complete.
```

## JSON Format

Recorded events are stored in JSON format:
```json
{
  "version": 1,
  "events": [
    {"t": 0, "type": "move", "x": 500, "y": 300},
    {"t": 150, "type": "left_down", "x": 500, "y": 300},
    {"t": 200, "type": "left_up", "x": 500, "y": 300},
    {"t": 500, "type": "key_down", "x": 0, "y": 0, "data": 65},
    {"t": 550, "type": "key_up", "x": 0, "y": 0, "data": 65}
  ]
}
```

- `t`: Timestamp in milliseconds since recording started
- `type`: Event type (move, left_down, left_up, right_down, right_up, wheel, key_down, key_up)
- `x`, `y`: Mouse coordinates (0 for keyboard events)
- `data`: Virtual key code for keyboard, wheel delta for scroll

## Design Decisions

| Aspect | Rationale |
|--------|-----------|
| **Module separation** | Each module has a single responsibility, making code easier to test, maintain, and extend |
| **Win32 bindings in separate module** | Isolates platform-specific code and makes it easy to add support for other platforms |
| **Coordinate normalization** | Windows expects 0–65535 absolute coordinates; conversion centralized in `coordinates.zig` |
| **Input operations abstraction** | Higher-level functions hide the complexity of `SendInput` |
| **Threaded hooks** | Recording hooks run in separate thread with message pump to capture events while REPL waits for input |
| **Manual JSON parsing** | Avoids external dependencies; simple format is easy to parse |
| **Error handling** | All parsing errors return `CommandError`, caught at the REPL level for user-friendly messages |

## Requirements

- **OS**: Windows
- **Zig Version**: 0.16.0-dev (uses new std.Io and std.process.Init APIs)
- **Build Tool**: Zig build system (no external dependencies)

## Future Extensions

This modular structure makes it easy to add:
- **Configuration file** – Parse command aliases from a config file
- **Web API** – Expose commands via HTTP API
- **Logging** – Add detailed operation logging
- **GUI launcher** – Create a simple window for command entry
- **Macro editor** – Visual editor for recorded macros
