# Mouse Controller (Modular Zig Implementation)

A command-line mouse controller for Windows that interprets text commands and executes corresponding mouse actions using Win32 API via Zig's C interop.

## Modular Architecture

The implementation is organized into focused modules:

### `src/main.zig`
**Entry point and REPL loop**
- Initializes the console
- Retrieves screen dimensions via `GetSystemMetrics`
- Implements the read-eval-print loop
- Handles EOF and quit commands

### `src/win32.zig`
**Win32 API bindings**
- Constants: `MOUSEEVENTF_*`, screen metrics IDs (`SM_CXSCREEN`, `SM_CYSCREEN`)
- Structures: `MOUSEINPUT` and `INPUT` (extern structs for C ABI compatibility)
- Extern function declarations: `SendInput`, `GetSystemMetrics`
- Compile-time ABI validation

### `src/coordinates.zig`
**Coordinate mapping utilities**
- `toAbsoluteX()` – Convert pixel X to 0–65535 normalized range
- `toAbsoluteY()` – Convert pixel Y to 0–65535 normalized range
- Uses 64-bit intermediate arithmetic to prevent overflow

### `src/mouse.zig`
**Low-level mouse operations**
- `moveMouse()` – Move to absolute pixel coordinates
- `leftClick()`, `rightClick()`, `doubleClick()` – Click operations
- `scrollWheel()` – Scroll up (positive) or down (negative)
- Uses Win32 `SendInput` for all operations

### `src/commands.zig`
**Command parsing and dispatch**
- `parseXY()` – Parse "X-Y" coordinate pairs
- `execute*()` functions – Handlers for m, c, r, d, sc, sd commands
- `runCommand()` – Main dispatcher that routes commands
- `printHelp()` – Display available commands and screen resolution

### `build.zig`
**Zig build configuration**
- Defines build targets
- Configures optimization levels
- Provides `zig build` and `zig build run` commands

## Command Syntax

| Command        | Action                                      |
|----------------|---------------------------------------------|
| m\<X\>-\<Y\>   | Move mouse to x=X, y=Y                      |
| c\<X\>-\<Y\>   | Move and left-click                         |
| r\<X\>-\<Y\>   | Move and right-click                        |
| d\<X\>-\<Y\>   | Move and double-click                       |
| sc\<N\>        | Scroll up by N units                        |
| sd\<N\>        | Scroll down by N units                      |
| q              | Quit the program                            |

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

```
> m500-300
  Mouse moved to (500, 300)

> c120-150
  Mouse moved to (120, 150) and clicked

> r200-400
  Mouse moved to (200, 400) and right-clicked

> d100-100
  Mouse moved to (100, 100) and double-clicked

> sc30
  Scrolled up by 30

> sd15
  Scrolled down by 15

> q
  Exiting...
```

## Design Decisions

| Aspect | Rationale |
|--------|-----------|
| **Module separation** | Each module has a single responsibility, making code easier to test, maintain, and extend |
| **Win32 bindings in separate module** | Isolates platform-specific code and makes it easy to add support for other platforms |
| **Coordinate normalization** | Windows expects 0–65535 absolute coordinates; conversion centralized in `coordinates.zig` |
| **Mouse operations abstraction** | Higher-level functions (`leftClick`, `doubleClick`, etc.) hide the complexity of `SendInput` |
| **Error handling** | All parsing errors return `CommandError`, caught at the REPL level for user-friendly messages |
| **Extern struct layout** | `INPUT` uses C ABI rules; compile-time assertion verifies size matches Win32 specification |

## Requirements

- **OS**: Windows
- **Zig Version**: 0.13.0 or later (tested with 0.16.0-dev)
- **Build Tool**: Zig build system (no external dependencies)

## Future Extensions

This modular structure makes it easy to add:
- **Keyboard simulation** – Create `keyboard.zig` for SendInput keyboard events
- **Configuration file** – Parse command aliases from a config file
- **Record/playback** – Store and replay mouse sequences
- **Web API** – Expose commands via HTTP API
- **Logging** – Add detailed operation logging
- **GUI launcher** – Create a simple window for command entry
