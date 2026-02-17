//! Coordinate mapping utilities
//! Converts pixel coordinates to the 0–65535 absolute range used by Windows

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
