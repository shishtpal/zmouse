//! Win32 API bindings for mouse control
//! Defines constants, structures, and extern function declarations for user32.dll

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════
//  Win32 constants
// ═══════════════════════════════════════════════════════════════════════

pub const SM_CXSCREEN: c_int = 0;
pub const SM_CYSCREEN: c_int = 1;
pub const INPUT_MOUSE: u32 = 0;

pub const MOUSEEVENTF_MOVE: u32 = 0x0001;
pub const MOUSEEVENTF_LEFTDOWN: u32 = 0x0002;
pub const MOUSEEVENTF_LEFTUP: u32 = 0x0004;
pub const MOUSEEVENTF_RIGHTDOWN: u32 = 0x0008;
pub const MOUSEEVENTF_RIGHTUP: u32 = 0x0010;
pub const MOUSEEVENTF_WHEEL: u32 = 0x0800;
pub const MOUSEEVENTF_ABSOLUTE: u32 = 0x8000;

pub const WHEEL_DELTA: i32 = 120;

// ═══════════════════════════════════════════════════════════════════════
//  Win32 structures (extern → C ABI layout)
// ═══════════════════════════════════════════════════════════════════════

pub const POINT = extern struct {
    x: c_long,
    y: c_long,
};

pub const MOUSEINPUT = extern struct {
    dx: i32 = 0,
    dy: i32 = 0,
    mouseData: u32 = 0,
    dwFlags: u32 = 0,
    time: u32 = 0,
    dwExtraInfo: usize = 0,
};

/// We only ever send mouse events, so we embed MOUSEINPUT directly.
/// MOUSEINPUT is the largest union member in the real Win32 INPUT struct,
/// so the sizes match.
pub const INPUT = extern struct {
    input_type: u32 = 0, // "type" is a Zig keyword, renamed here
    mi: MOUSEINPUT = .{},
};

// Compile-time proof that our struct matches the Win32 layout.
comptime {
    const expected: usize = if (@sizeOf(usize) == 8) 40 else 28;
    if (@sizeOf(INPUT) != expected)
        @compileError("INPUT struct size does not match the Win32 ABI");
}

// ═══════════════════════════════════════════════════════════════════════
//  Win32 imports (user32.dll)
// ═══════════════════════════════════════════════════════════════════════

pub extern "user32" fn SendInput(
    cInputs: u32,
    pInputs: [*]INPUT,
    cbSize: c_int,
) callconv(.winapi) u32;

pub extern "user32" fn GetSystemMetrics(
    nIndex: c_int,
) callconv(.winapi) c_int;

pub extern "user32" fn GetCursorPos(
    lpPoint: *POINT,
) callconv(.winapi) c_int;
