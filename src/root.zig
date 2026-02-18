//! ZMouse - Windows Input Controller Library
//!
//! A library for controlling mouse and keyboard input on Windows,
//! with support for recording, playback, and HTTP API.
//!
//! ## Features
//!
//! - Mouse movement, clicking, and scrolling
//! - Keyboard input simulation
//! - Input event recording and playback
//! - HTTP REST API for remote control
//! - Screenshot capture
//!
//! ## Example Usage
//!
//! ```zig
//! const zmouse = @import("zmouse");
//!
//! pub fn main() !void {
//!     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//!     defer _ = gpa.deinit();
//!     const allocator = gpa.allocator();
//!
//!     // Get screen dimensions
//!     const screen = try zmouse.input.getScreenDimensions();
//!
//!     // Move mouse
//!     try zmouse.input.moveMouse(500, 300, screen);
//!
//!     // Click
//!     zmouse.input.leftClick();
//!
//!     // Recording
//!     var recorder = zmouse.Recorder.init(allocator);
//!     defer recorder.deinit();
//!
//!     try recorder.startRecording();
//!     // ... user performs actions ...
//!     recorder.stopRecording();
//!
//!     // Save events
//!     const events = recorder.getEvents();
//!     try zmouse.storage.saveEvents(events, "macro.json", allocator);
//! }
//! ```

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════
//  Modules
// ═══════════════════════════════════════════════════════════════════════

pub const errors = @import("errors.zig");
pub const input = @import("mouse.zig");
pub const recorder = @import("recorder.zig");
pub const server = @import("http_server.zig");
pub const storage = @import("json_io.zig");
pub const screenshot = @import("screenshot.zig");
pub const coordinates = @import("coordinates.zig");
pub const commands = @import("commands.zig");

// Internal Win32 bindings (available but not part of public API)
pub const win32 = @import("win32.zig");

// ═══════════════════════════════════════════════════════════════════════
//  Re-exported Types (Public API)
// ═══════════════════════════════════════════════════════════════════════

/// Input event types
pub const EventType = recorder.EventType;

/// Recorded input event
pub const Event = recorder.Event;

/// Screen dimensions
pub const ScreenDimensions = input.ScreenDimensions;

/// Mouse position
pub const MousePosition = input.MousePosition;

/// Input event recorder
pub const Recorder = recorder.Recorder;

/// HTTP server
pub const Server = server.Server;

/// Captured screenshot
pub const Screenshot = screenshot.Screenshot;

// ═══════════════════════════════════════════════════════════════════════
//  Error Types
// ═══════════════════════════════════════════════════════════════════════

pub const InputError = errors.InputError;
pub const RecorderError = errors.RecorderError;
pub const ServerError = errors.ServerError;
pub const StorageError = errors.StorageError;
pub const ScreenshotError = errors.ScreenshotError;
pub const CommandError = errors.CommandError;

/// Union of all zmouse errors
pub const ZMouseError = errors.ZMouseError;

// ═══════════════════════════════════════════════════════════════════════
//  Version
// ═══════════════════════════════════════════════════════════════════════

pub const version = struct {
    pub const major: u32 = 1;
    pub const minor: u32 = 0;
    pub const patch: u32 = 0;
};

// ═══════════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════════

test {
    // Run all tests from imported modules
    _ = errors;
    _ = input;
    _ = recorder;
    _ = coordinates;
}

test "version" {
    try std.testing.expectEqual(@as(u32, 1), version.major);
    try std.testing.expectEqual(@as(u32, 0), version.minor);
}
