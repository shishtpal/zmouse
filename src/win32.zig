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
pub const WH_KEYBOARD_LL: c_int = 13;

// Mouse message constants
pub const WM_MOUSEMOVE: u32 = 0x0200;
pub const WM_LBUTTONDOWN: u32 = 0x0201;
pub const WM_LBUTTONUP: u32 = 0x0202;
pub const WM_RBUTTONDOWN: u32 = 0x0204;
pub const WM_RBUTTONUP: u32 = 0x0205;
pub const WM_MOUSEWHEEL: u32 = 0x020A;

// Keyboard message constants
pub const WM_KEYDOWN: u32 = 0x0100;
pub const WM_KEYUP: u32 = 0x0101;
pub const WM_SYSKEYDOWN: u32 = 0x0104;
pub const WM_SYSKEYUP: u32 = 0x0105;

// Keyboard input constants
pub const INPUT_KEYBOARD: u32 = 1;
pub const KEYEVENTF_KEYUP: u32 = 0x0002;

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

/// INPUT struct for SendInput - supports both mouse and keyboard input.
/// Uses a union to handle different input types.
pub const INPUT = extern struct {
    input_type: u32 = 0, // "type" is a Zig keyword, renamed here
    data: extern union {
        mi: MOUSEINPUT,
        ki: KEYBDINPUT,
    } = .{ .mi = .{} },
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

pub const KBDLLHOOKSTRUCT = extern struct {
    vkCode: u32,
    scanCode: u32,
    flags: u32,
    time: u32,
    dwExtraInfo: usize,
};

pub const KEYBDINPUT = extern struct {
    wVk: u16 = 0,
    wScan: u16 = 0,
    dwFlags: u32 = 0,
    time: u32 = 0,
    dwExtraInfo: usize = 0,
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

// ═══════════════════════════════════════════════════════════════════════
//  Win32 Socket constants and types
// ═══════════════════════════════════════════════════════════════════════

pub const SOCK_STREAM: i32 = 1;
pub const AF_INET: i32 = 2;
pub const IPPROTO_TCP: i32 = 6;
pub const SOMAXCONN: i32 = 0x7fffffff;

pub const SOCKET = usize;
pub const INVALID_SOCKET: SOCKET = @bitCast(@as(isize, -1));
pub const SOCKET_ERROR: i32 = -1;

pub const SOCKADDR_IN = extern struct {
    sin_family: u16,
    sin_port: u16,
    sin_addr: u32,
    sin_zero: [8]u8 = .{0} ** 8,
};

pub const WSAData = extern struct {
    wVersion: u16,
    wHighVersion: u16,
    szDescription: [257]u8,
    szSystemStatus: [129]u8,
    iMaxSockets: u16,
    iMaxUdpDg: u16,
    lpVendorInfo: ?*anyopaque,
};

// ═══════════════════════════════════════════════════════════════════════
//  Win32 GDI constants and types (for screenshots)
// ═══════════════════════════════════════════════════════════════════════

pub const HDC = *opaque {};
pub const HBITMAP = *opaque {};
pub const HGDIOBJ = *opaque {};

pub const BI_RGB: u32 = 0;
pub const DIB_RGB_COLORS: u32 = 0;
pub const SRCCOPY: u32 = 0x00CC0020;

pub const BITMAPINFOHEADER = extern struct {
    biSize: u32,
    biWidth: c_long,
    biHeight: c_long,
    biPlanes: u16,
    biBitCount: u16,
    biCompression: u32,
    biSizeImage: u32,
    biXPelsPerMeter: c_long,
    biYPelsPerMeter: c_long,
    biClrUsed: u32,
    biClrImportant: u32,
};

pub const BITMAPINFO = extern struct {
    bmiHeader: BITMAPINFOHEADER,
    bmiColors: [1]u32, // Placeholder for color table
};

// ═══════════════════════════════════════════════════════════════════════
//  Win32 Socket imports (ws2_32.dll)
// ═══════════════════════════════════════════════════════════════════════

pub extern "ws2_32" fn WSAStartup(
    wVersionRequired: u16,
    lpWSAData: *WSAData,
) callconv(.winapi) i32;

pub extern "ws2_32" fn WSACleanup() callconv(.winapi) i32;

pub extern "ws2_32" fn socket(
    af: i32,
    type: i32,
    protocol: i32,
) callconv(.winapi) SOCKET;

pub extern "ws2_32" fn bind(
    s: SOCKET,
    name: *const SOCKADDR_IN,
    namelen: i32,
) callconv(.winapi) i32;

pub extern "ws2_32" fn listen(
    s: SOCKET,
    backlog: i32,
) callconv(.winapi) i32;

pub extern "ws2_32" fn accept(
    s: SOCKET,
    addr: ?*SOCKADDR_IN,
    addrlen: ?*i32,
) callconv(.winapi) SOCKET;

pub extern "ws2_32" fn recv(
    s: SOCKET,
    buf: [*]u8,
    len: i32,
    flags: i32,
) callconv(.winapi) i32;

pub extern "ws2_32" fn send(
    s: SOCKET,
    buf: [*]const u8,
    len: i32,
    flags: i32,
) callconv(.winapi) i32;

pub extern "ws2_32" fn closesocket(
    s: SOCKET,
) callconv(.winapi) i32;

pub extern "ws2_32" fn ioctlsocket(
    s: SOCKET,
    cmd: u32,
    argp: *u32,
) callconv(.winapi) i32;

pub const FIONBIO: u32 = 0x8004667E;
pub const SOL_SOCKET: i32 = 0xFFFF;
pub const SO_RCVTIMEO: i32 = 0x1006;

pub extern "ws2_32" fn setsockopt(
    s: SOCKET,
    level: i32,
    optname: i32,
    optval: [*]const u8,
    optlen: i32,
) callconv(.winapi) i32;

// ═══════════════════════════════════════════════════════════════════════
//  Win32 GDI imports (gdi32.dll and user32.dll)
// ═══════════════════════════════════════════════════════════════════════

pub extern "user32" fn GetDC(
    hWnd: ?HWND,
) callconv(.winapi) ?HDC;

pub extern "user32" fn ReleaseDC(
    hWnd: ?HWND,
    hDC: HDC,
) callconv(.winapi) c_int;

pub extern "user32" fn GetDesktopWindow() callconv(.winapi) ?HWND;

pub extern "gdi32" fn CreateCompatibleDC(
    hDC: HDC,
) callconv(.winapi) ?HDC;

pub extern "gdi32" fn CreateCompatibleBitmap(
    hDC: HDC,
    width: c_int,
    height: c_int,
) callconv(.winapi) ?HBITMAP;

pub extern "gdi32" fn SelectObject(
    hDC: HDC,
    hGdiObj: HGDIOBJ,
) callconv(.winapi) HGDIOBJ;

pub extern "gdi32" fn BitBlt(
    hDestDC: HDC,
    x: c_int,
    y: c_int,
    nWidth: c_int,
    nHeight: c_int,
    hSrcDC: HDC,
    xSrc: c_int,
    ySrc: c_int,
    dwRop: u32,
) callconv(.winapi) c_int;

pub extern "gdi32" fn GetDIBits(
    hDC: HDC,
    hbm: HBITMAP,
    start: u32,
    cLines: u32,
    lpvBits: ?*anyopaque,
    lpbmi: *BITMAPINFO,
    usage: u32,
) callconv(.winapi) c_int;

pub extern "gdi32" fn DeleteObject(
    hGdiObj: HGDIOBJ,
) callconv(.winapi) c_int;

pub extern "gdi32" fn DeleteDC(
    hDC: HDC,
) callconv(.winapi) c_int;
