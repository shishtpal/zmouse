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

// Hook constants
pub const WH_MOUSE_LL: c_int = 14;

// Mouse message constants
pub const WM_MOUSEMOVE: u32 = 0x0200;
pub const WM_LBUTTONDOWN: u32 = 0x0201;
pub const WM_LBUTTONUP: u32 = 0x0202;
pub const WM_RBUTTONDOWN: u32 = 0x0204;
pub const WM_RBUTTONUP: u32 = 0x0205;
pub const WM_MOUSEWHEEL: u32 = 0x020A;

// Message loop constants
pub const PM_REMOVE: u32 = 0x0001;

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

// ═══════════════════════════════════════════════════════════════════════
//  Hook-related structures
// ═══════════════════════════════════════════════════════════════════════

pub const HHOOK = *opaque {};
pub const HINSTANCE = *opaque {};
pub const HWND = *opaque {};

pub const MSLLHOOKSTRUCT = extern struct {
    pt: POINT,
    mouseData: u32,
    flags: u32,
    time: u32,
    dwExtraInfo: usize,
};

pub const MSG = extern struct {
    hwnd: ?HWND,
    message: u32,
    wParam: usize,
    lParam: isize,
    time: u32,
    pt: POINT,
};

pub const HOOKPROC = *const fn (code: c_int, wParam: usize, lParam: isize) callconv(.winapi) isize;

// ═══════════════════════════════════════════════════════════════════════
//  Hook and message loop imports
// ═══════════════════════════════════════════════════════════════════════

pub extern "user32" fn SetWindowsHookExW(
    idHook: c_int,
    lpfn: HOOKPROC,
    hmod: ?HINSTANCE,
    dwThreadId: u32,
) callconv(.winapi) ?HHOOK;

pub extern "user32" fn UnhookWindowsHookEx(
    hhk: HHOOK,
) callconv(.winapi) c_int;

pub extern "user32" fn CallNextHookEx(
    hhk: ?HHOOK,
    nCode: c_int,
    wParam: usize,
    lParam: isize,
) callconv(.winapi) isize;

pub extern "user32" fn PeekMessageW(
    lpMsg: *MSG,
    hWnd: ?HWND,
    wMsgFilterMin: u32,
    wMsgFilterMax: u32,
    wRemoveMsg: u32,
) callconv(.winapi) c_int;

pub extern "user32" fn TranslateMessage(
    lpMsg: *const MSG,
) callconv(.winapi) c_int;

pub extern "user32" fn DispatchMessageW(
    lpMsg: *const MSG,
) callconv(.winapi) isize;

pub extern "kernel32" fn GetTickCount64() callconv(.winapi) u64;

pub extern "kernel32" fn Sleep(
    dwMilliseconds: u32,
) callconv(.winapi) void;

pub extern "kernel32" fn CreateThread(
    lpThreadAttributes: ?*anyopaque,
    dwStackSize: usize,
    lpStartAddress: *const fn (?*anyopaque) callconv(.winapi) u32,
    lpParameter: ?*anyopaque,
    dwCreationFlags: u32,
    lpThreadId: ?*u32,
) callconv(.winapi) ?HANDLE;

pub extern "kernel32" fn WaitForSingleObject(
    hHandle: HANDLE,
    dwMilliseconds: u32,
) callconv(.winapi) u32;

pub const HANDLE = *opaque {};
pub const INFINITE: u32 = 0xFFFFFFFF;
