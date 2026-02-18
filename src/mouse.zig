//! Low-level mouse control operations
//! Provides abstractions for moving the mouse, clicking, and scrolling

const win32 = @import("win32.zig");
const coord = @import("coordinates.zig");

/// Move the mouse to absolute pixel coordinates
pub fn moveMouse(x: i32, y: i32, screen_width: c_int, screen_height: c_int) void {
    var buf = [1]win32.INPUT{.{
        .input_type = win32.INPUT_MOUSE,
        .data = .{ .mi = .{
            .dx = coord.toAbsoluteX(x, screen_width),
            .dy = coord.toAbsoluteY(y, screen_height),
            .dwFlags = win32.MOUSEEVENTF_MOVE | win32.MOUSEEVENTF_ABSOLUTE,
        } },
    }};
    _ = win32.SendInput(1, &buf, @sizeOf(win32.INPUT));
}

/// Click a mouse button (down and up)
pub fn clickButton(down_flag: u32, up_flag: u32) void {
    var buf = [2]win32.INPUT{
        .{ .input_type = win32.INPUT_MOUSE, .data = .{ .mi = .{ .dwFlags = down_flag } } },
        .{ .input_type = win32.INPUT_MOUSE, .data = .{ .mi = .{ .dwFlags = up_flag } } },
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
        .data = .{ .mi = .{
            // mouseData is DWORD but the wheel value is signed;
            // @bitCast reinterprets the i32 bits as u32.
            .mouseData = @bitCast(amount * win32.WHEEL_DELTA),
            .dwFlags = win32.MOUSEEVENTF_WHEEL,
        } },
    }};
    _ = win32.SendInput(1, &buf, @sizeOf(win32.INPUT));
}

/// Send a key press or release
pub fn sendKey(vk: u16, key_up: bool) void {
    var buf = [1]win32.INPUT{.{
        .input_type = win32.INPUT_KEYBOARD,
        .data = .{ .ki = .{
            .wVk = vk,
            .dwFlags = if (key_up) win32.KEYEVENTF_KEYUP else 0,
        } },
    }};
    _ = win32.SendInput(1, &buf, @sizeOf(win32.INPUT));
}

/// Get the current mouse cursor position
pub fn getPosition() ?struct { x: c_long, y: c_long } {
    var point: win32.POINT = .{ .x = 0, .y = 0 };
    if (win32.GetCursorPos(&point) != 0) {
        return .{ .x = point.x, .y = point.y };
    }
    return null;
}
