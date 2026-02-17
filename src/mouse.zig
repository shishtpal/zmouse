//! Low-level mouse control operations
//! Provides abstractions for moving the mouse, clicking, and scrolling

const win32 = @import("win32.zig");
const coord = @import("coordinates.zig");

/// Move the mouse to absolute pixel coordinates
pub fn moveMouse(x: i32, y: i32, screen_width: c_int, screen_height: c_int) void {
    var buf = [1]win32.INPUT{.{
        .input_type = win32.INPUT_MOUSE,
        .mi = .{
            .dx = coord.toAbsoluteX(x, screen_width),
            .dy = coord.toAbsoluteY(y, screen_height),
            .dwFlags = win32.MOUSEEVENTF_MOVE | win32.MOUSEEVENTF_ABSOLUTE,
        },
    }};
    _ = win32.SendInput(1, &buf, @sizeOf(win32.INPUT));
}

/// Click a mouse button (down and up)
pub fn clickButton(down_flag: u32, up_flag: u32) void {
    var buf = [2]win32.INPUT{
        .{ .input_type = win32.INPUT_MOUSE, .mi = .{ .dwFlags = down_flag } },
        .{ .input_type = win32.INPUT_MOUSE, .mi = .{ .dwFlags = up_flag } },
    };
    _ = win32.SendInput(2, &buf, @sizeOf(win32.INPUT));
}

/// Left-click at current position
pub fn leftClick() void {
    clickButton(win32.MOUSEEVENTF_LEFTDOWN, win32.MOUSEEVENTF_LEFTUP);
}

/// Right-click at current position
pub fn rightClick() void {
    clickButton(win32.MOUSEEVENTF_RIGHTDOWN, win32.MOUSEEVENTF_RIGHTUP);
}

/// Double-click at current position
pub fn doubleClick() void {
    leftClick();
    leftClick();
}

/// Scroll the mouse wheel (positive = up, negative = down)
pub fn scrollWheel(amount: i32) void {
    var buf = [1]win32.INPUT{.{
        .input_type = win32.INPUT_MOUSE,
        .mi = .{
            // mouseData is DWORD but the wheel value is signed;
            // @bitCast reinterprets the i32 bits as u32.
            .mouseData = @bitCast(amount * win32.WHEEL_DELTA),
            .dwFlags = win32.MOUSEEVENTF_WHEEL,
        },
    }};
    _ = win32.SendInput(1, &buf, @sizeOf(win32.INPUT));
}
