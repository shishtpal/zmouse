//! Low-level input control operations
//! Provides abstractions for moving the mouse, clicking, scrolling, and keyboard input
//!
//! Example usage:
//! ```zig
//! const screen = input.getScreenDimensions() catch return;
//!
//! // Move mouse
//! try input.moveMouse(500, 300, screen);
//!
//! // Click
//! input.leftClick();
//!
//! // Get position
//! const pos = input.getPosition() orelse return;
//! print("Mouse at ({}, {})\n", .{ pos.x, pos.y });
//! ```

const std = @import("std");
const win32 = @import("win32.zig");
const coord = @import("coordinates.zig");
const errors = @import("errors.zig");

// ═══════════════════════════════════════════════════════════════════════
//  Screen Dimensions
// ═══════════════════════════════════════════════════════════════════════

/// Screen dimensions for coordinate mapping
pub const ScreenDimensions = struct {
    width: c_int,
    height: c_int,

    /// Check if dimensions are valid
    pub fn isValid(self: ScreenDimensions) bool {
        return self.width > 1 and self.height > 1;
    }
};

/// Get the primary monitor dimensions
pub fn getScreenDimensions() errors.InputError!ScreenDimensions {
    const width = win32.GetSystemMetrics(win32.SM_CXSCREEN);
    const height = win32.GetSystemMetrics(win32.SM_CYSCREEN);

    if (width <= 1 or height <= 1) {
        return error.ScreenDimensionsInvalid;
    }

    return .{ .width = width, .height = height };
}

// ═══════════════════════════════════════════════════════════════════════
//  Mouse Position
// ═══════════════════════════════════════════════════════════════════════

/// Mouse position coordinates
pub const MousePosition = struct {
    x: c_long,
    y: c_long,
};

/// Get the current mouse cursor position
pub fn getPosition() ?MousePosition {
    var point: win32.POINT = std.mem.zeroes(win32.POINT);
    if (win32.GetCursorPos(&point) != 0) {
        return .{ .x = point.x, .y = point.y };
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════════
//  Mouse Movement
// ═══════════════════════════════════════════════════════════════════════

/// Move the mouse to absolute pixel coordinates
pub fn moveMouse(x: i32, y: i32, screen: ScreenDimensions) errors.InputError!void {
    if (!screen.isValid()) return error.ScreenDimensionsInvalid;

    var buf = [1]win32.INPUT{.{
        .input_type = win32.INPUT_MOUSE,
        .data = .{ .mi = .{
            .dx = coord.toAbsoluteX(x, screen.width),
            .dy = coord.toAbsoluteY(y, screen.height),
            .dwFlags = win32.MOUSEEVENTF_MOVE | win32.MOUSEEVENTF_ABSOLUTE,
        } },
    }};

    const sent = win32.SendInput(1, &buf, @sizeOf(win32.INPUT));
    if (sent == 0) return error.SendInputFailed;
}

/// Move mouse to coordinates and click
pub fn moveAndClick(x: i32, y: i32, screen: ScreenDimensions) errors.InputError!void {
    try moveMouse(x, y, screen);
    leftClick();
}

// ═══════════════════════════════════════════════════════════════════════
//  Mouse Clicks
// ═══════════════════════════════════════════════════════════════════════

/// Send a single mouse event (for playback)
pub fn sendMouseEvent(flags: u32) void {
    var buf = [1]win32.INPUT{
        .{ .input_type = win32.INPUT_MOUSE, .data = .{ .mi = .{ .dwFlags = flags } } },
    };
    _ = win32.SendInput(1, &buf, @sizeOf(win32.INPUT));
}

/// Click a mouse button (down and up)
fn clickButton(down_flag: u32, up_flag: u32) void {
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

// ═══════════════════════════════════════════════════════════════════════
//  Mouse Scroll
// ═══════════════════════════════════════════════════════════════════════

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

/// Scroll up by the specified amount
pub fn scrollUp(amount: i32) void {
    scrollWheel(amount);
}

/// Scroll down by the specified amount
pub fn scrollDown(amount: i32) void {
    scrollWheel(-amount);
}

// ═══════════════════════════════════════════════════════════════════════
//  Keyboard Input
// ═══════════════════════════════════════════════════════════════════════

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

/// Press and release a key
pub fn pressKey(vk: u16) void {
    sendKey(vk, false);
    sendKey(vk, true);
}

/// Press a key down (without releasing)
pub fn keyDown(vk: u16) void {
    sendKey(vk, false);
}

/// Release a key
pub fn keyUp(vk: u16) void {
    sendKey(vk, true);
}

// ═══════════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════════

test "ScreenDimensions.isValid" {
    const valid = ScreenDimensions{ .width = 1920, .height = 1080 };
    try std.testing.expect(valid.isValid());

    const invalid1 = ScreenDimensions{ .width = 0, .height = 1080 };
    try std.testing.expect(!invalid1.isValid());

    const invalid2 = ScreenDimensions{ .width = 1, .height = 1 };
    try std.testing.expect(!invalid2.isValid());
}

test "MousePosition struct" {
    const pos = MousePosition{ .x = 500, .y = 300 };
    try std.testing.expectEqual(@as(c_long, 500), pos.x);
    try std.testing.expectEqual(@as(c_long, 300), pos.y);
}
