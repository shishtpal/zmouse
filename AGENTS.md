# AGENTS.md

Guidelines for AI coding agents working on this project.

## Project Overview

**zmouse** is a Windows command-line mouse controller written in Zig. It reads text commands from stdin and executes mouse actions using Win32 API via Zig's C interop.

## Zig Version

This project uses **Zig 0.16.0-dev** which has significant breaking changes from 0.13/0.14/0.15:

- `std.io` is replaced by `std.Io`
- `main()` takes `std.process.Init` parameter for I/O access
- `callconv(.winapi)` instead of `WINAPI` constant
- `c_int` is now a primitive type (don't redeclare it)
- Build API uses `root_module` with `b.createModule()` instead of `root_source_file`

## Project Structure

```
zmouse/
├── build.zig           # Zig build configuration
├── src/
│   ├── main.zig        # Entry point and REPL loop
│   ├── win32.zig       # Win32 API bindings (SendInput, GetSystemMetrics)
│   ├── coordinates.zig # Pixel to absolute coordinate conversion
│   ├── mouse.zig       # High-level mouse operations
│   └── commands.zig    # Command parsing and dispatch
├── PRD.md              # Product requirements document
└── README.md           # User documentation
```

## Module Responsibilities

| Module | Purpose |
|--------|---------|
| `main.zig` | REPL loop, stdin reading, screen metrics initialization |
| `win32.zig` | Win32 constants, structs (`INPUT`, `MOUSEINPUT`), extern fn declarations |
| `coordinates.zig` | `toAbsoluteX/Y()` - convert pixels to 0-65535 range |
| `mouse.zig` | `moveMouse()`, `leftClick()`, `rightClick()`, `doubleClick()`, `scrollWheel()` |
| `commands.zig` | `runCommand()` - parse and dispatch commands like `m120-150`, `c500-300`, `sc10` |

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

## Command Syntax

| Command | Action |
|---------|--------|
| `m<X>-<Y>` | Move mouse to (X, Y) |
| `c<X>-<Y>` | Move and left-click |
| `r<X>-<Y>` | Move and right-click |
| `d<X>-<Y>` | Move and double-click |
| `sc<N>` | Scroll up by N units |
| `sd<N>` | Scroll down by N units |
| `q` | Quit |

## Testing

No automated tests currently. Manual testing:

1. Run `zig build run`
2. Enter commands like `m500-300`, `c100-100`, `sc5`
3. Verify mouse moves/clicks correctly
4. Enter `q` to quit

## Platform Notes

- **Windows only** - uses `user32.dll` via Zig's C interop
- Coordinates are normalized to 0-65535 range for `MOUSEEVENTF_ABSOLUTE`
- `SendInput` is used for all mouse operations
- Screen dimensions from `GetSystemMetrics(SM_CXSCREEN/SM_CYSCREEN)`
