//! Coordinate mapping utilities
//! Converts pixel coordinates to the 0–65535 absolute range used by Windows
//!
//! Windows uses a normalized coordinate system for absolute mouse positioning
//! where (0,0) is the top-left and (65535,65535) is the bottom-right of the
//! primary monitor, regardless of actual screen resolution.

/// Map a pixel X coordinate to the 0–65535 absolute range that
/// MOUSEEVENTF_ABSOLUTE expects.
pub fn toAbsoluteX(x: i32, screen_w: c_int) i32 {
    return @intCast(@divTrunc(
        @as(i64, x) * 65535,
        @as(i64, screen_w - 1),
    ));
}

/// Map a pixel Y coordinate to the 0–65535 absolute range.
pub fn toAbsoluteY(y: i32, screen_h: c_int) i32 {
    return @intCast(@divTrunc(
        @as(i64, y) * 65535,
        @as(i64, screen_h - 1),
    ));
}

/// Convert from absolute (0-65535) back to pixel coordinates
pub fn fromAbsoluteX(absolute: i32, screen_w: c_int) i32 {
    return @intCast(@divTrunc(
        @as(i64, absolute) * (screen_w - 1),
        65535,
    ));
}

/// Convert from absolute (0-65535) back to pixel coordinates
pub fn fromAbsoluteY(absolute: i32, screen_h: c_int) i32 {
    return @intCast(@divTrunc(
        @as(i64, absolute) * (screen_h - 1),
        65535,
    ));
}

// ═══════════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════════

test "toAbsoluteX maps 0 to 0" {
    try std.testing.expectEqual(@as(i32, 0), toAbsoluteX(0, 1920));
}

test "toAbsoluteX maps screen_width-1 to 65535" {
    try std.testing.expectEqual(@as(i32, 65535), toAbsoluteX(1919, 1920));
}

test "toAbsoluteX maps midpoint correctly" {
    const mid = toAbsoluteX(960, 1920);
    // 960 * 65535 / 1919 ≈ 32793 (midpoint in absolute coords)
    // The value should be approximately half of 65535
    try std.testing.expect(mid > 32000 and mid < 34000);
}

test "toAbsoluteY maps 0 to 0" {
    try std.testing.expectEqual(@as(i32, 0), toAbsoluteY(0, 1080));
}

test "toAbsoluteY maps screen_height-1 to 65535" {
    try std.testing.expectEqual(@as(i32, 65535), toAbsoluteY(1079, 1080));
}

test "fromAbsoluteX reverses toAbsoluteX" {
    const original: i32 = 500;
    const absolute = toAbsoluteX(original, 1920);
    const back = fromAbsoluteX(absolute, 1920);
    // Should be close (within 1 pixel due to rounding)
    const diff = if (back > original) back - original else original - back;
    try std.testing.expect(diff <= 1);
}

test "fromAbsoluteY reverses toAbsoluteY" {
    const original: i32 = 300;
    const absolute = toAbsoluteY(original, 1080);
    const back = fromAbsoluteY(absolute, 1080);
    const diff = if (back > original) back - original else original - back;
    try std.testing.expect(diff <= 1);
}

const std = @import("std");
