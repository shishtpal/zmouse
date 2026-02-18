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

pub extern "gdi32" fn CreateDIBSection(
    hdc: ?HDC,
    pbmi: *const BITMAPINFO,
    usage: u32,
    ppvBits: *?*anyopaque,
    hSection: ?HANDLE,
    offset: u32,
) callconv(.winapi) ?HBITMAP;

// ═══════════════════════════════════════════════════════════════════════
//  GDI+ types and constants (for JPEG encoding)
// ═══════════════════════════════════════════════════════════════════════

pub const GpStatus = enum(c_int) {
    Ok = 0,
    GenericError = 1,
    InvalidParameter = 2,
    OutOfMemory = 3,
    ObjectBusy = 4,
    InsufficientBuffer = 5,
    NotImplemented = 6,
    Win32Error = 7,
    WrongState = 8,
    Aborted = 9,
    FileNotFound = 10,
    ValueOverflow = 11,
    AccessDenied = 12,
    UnknownImageFormat = 13,
    FontFamilyNotFound = 14,
    FontStyleNotFound = 15,
    NotTrueTypeFont = 16,
    UnsupportedGdiplusVersion = 17,
    GdiplusNotInitialized = 18,
    PropertyNotFound = 19,
    PropertyNotSupported = 20,
    ProfileNotFound = 21,
};

pub const GdiplusStartupInput = extern struct {
    GdiplusVersion: u32 = 1,
    DebugEventCallback: ?*anyopaque = null,
    SuppressBackgroundThread: c_int = 0,
    SuppressExternalCodecs: c_int = 0,
};

pub const GdiplusStartupOutput = extern struct {
    NotificationHook: ?*anyopaque = null,
    NotificationUnhook: ?*anyopaque = null,
};

pub const GUID = extern struct {
    Data1: u32,
    Data2: u16,
    Data3: u16,
    Data4: [8]u8,
};

pub const CLSID = GUID;

pub const EncoderParameter = extern struct {
    Guid: GUID,
    NumberOfValues: u32,
    Type: u32,
    Value: ?*anyopaque,
};

pub const EncoderParameters = extern struct {
    Count: u32,
    Parameter: [1]EncoderParameter,
};

pub const GpBitmap = opaque {};
pub const GpImage = opaque {};
pub const IStream = opaque {};

// Encoder parameter types
pub const EncoderParameterValueTypeLong: u32 = 4;

// JPEG encoder CLSID: {557CF401-1A04-11D3-9A73-0000F81EF32E}
pub const CLSID_JpegEncoder = CLSID{
    .Data1 = 0x557CF401,
    .Data2 = 0x1A04,
    .Data3 = 0x11D3,
    .Data4 = .{ 0x9A, 0x73, 0x00, 0x00, 0xF8, 0x1E, 0xF3, 0x2E },
};

// Encoder quality GUID: {1D5BE4B5-FA4A-452D-9CDD-5DB35105E7EB}
pub const EncoderQuality = GUID{
    .Data1 = 0x1D5BE4B5,
    .Data2 = 0xFA4A,
    .Data3 = 0x452D,
    .Data4 = .{ 0x9C, 0xDD, 0x5D, 0xB3, 0x51, 0x05, 0xE7, 0xEB },
};

// ═══════════════════════════════════════════════════════════════════════
//  GDI+ imports (gdiplus.dll)
// ═══════════════════════════════════════════════════════════════════════

pub extern "gdiplus" fn GdiplusStartup(
    token: *usize,
    input: *const GdiplusStartupInput,
    output: ?*GdiplusStartupOutput,
) callconv(.winapi) GpStatus;

pub extern "gdiplus" fn GdiplusShutdown(
    token: usize,
) callconv(.winapi) void;

pub extern "gdiplus" fn GdipCreateBitmapFromHBITMAP(
    hbm: HBITMAP,
    hpal: ?*anyopaque,
    bitmap: **GpBitmap,
) callconv(.winapi) GpStatus;

pub extern "gdiplus" fn GdipDisposeImage(
    image: *GpImage,
) callconv(.winapi) GpStatus;

pub extern "gdiplus" fn GdipSaveImageToStream(
    image: *GpImage,
    stream: *IStream,
    clsidEncoder: *const CLSID,
    encoderParams: ?*const EncoderParameters,
) callconv(.winapi) GpStatus;

// ═══════════════════════════════════════════════════════════════════════
//  OLE/COM imports for IStream (ole32.dll)
// ═══════════════════════════════════════════════════════════════════════

pub const HGLOBAL = *anyopaque;

pub extern "ole32" fn CreateStreamOnHGlobal(
    hGlobal: ?HGLOBAL,
    fDeleteOnRelease: c_int,
    ppstm: **IStream,
) callconv(.winapi) i32;

pub extern "kernel32" fn GlobalAlloc(
    uFlags: u32,
    dwBytes: usize,
) callconv(.winapi) ?HGLOBAL;

pub extern "kernel32" fn GlobalFree(
    hMem: HGLOBAL,
) callconv(.winapi) ?HGLOBAL;

pub extern "kernel32" fn GlobalLock(
    hMem: HGLOBAL,
) callconv(.winapi) ?*anyopaque;

pub extern "kernel32" fn GlobalUnlock(
    hMem: HGLOBAL,
) callconv(.winapi) c_int;

pub extern "kernel32" fn GlobalSize(
    hMem: HGLOBAL,
) callconv(.winapi) usize;

pub const GMEM_MOVEABLE: u32 = 0x0002;

// IStream VTable for Release and GetHGlobalFromStream
pub const IStreamVtbl = extern struct {
    QueryInterface: *const fn (*IStream, *const GUID, **anyopaque) callconv(.winapi) i32,
    AddRef: *const fn (*IStream) callconv(.winapi) u32,
    Release: *const fn (*IStream) callconv(.winapi) u32,
    // ... more methods we don't need
};

pub extern "ole32" fn GetHGlobalFromStream(
    pstm: *IStream,
    phglobal: *HGLOBAL,
) callconv(.winapi) i32;
