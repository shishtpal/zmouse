//! Input event recording and playback
//! Captures system-level input events using Win32 low-level hooks
//!
//! Example usage:
//! ```zig
//! var recorder = Recorder.init(allocator);
//! defer recorder.deinit();
//!
//! try recorder.startRecording();
//! // ... user performs actions ...
//! recorder.stopRecording();
//!
//! const events = recorder.getEvents();
//! ```

const std = @import("std");
const win32 = @import("win32.zig");
const errors = @import("errors.zig");

// ═══════════════════════════════════════════════════════════════════════
//  Event Types
// ═══════════════════════════════════════════════════════════════════════

/// Types of input events that can be recorded
pub const EventType = enum {
    // Mouse events
    move,
    left_down,
    left_up,
    right_down,
    right_up,
    wheel,
    // Keyboard events
    key_down,
    key_up,

    /// Convert event type to string for JSON serialization
    pub fn toString(self: EventType) []const u8 {
        return @tagName(self);
    }

    /// Parse event type from string (for JSON deserialization)
    pub fn fromString(s: []const u8) ?EventType {
        return std.meta.stringToEnum(EventType, s);
    }
};

/// A single recorded input event
pub const Event = struct {
    /// Milliseconds since recording started
    timestamp_ms: i64,
    /// Type of input event
    event_type: EventType,
    /// X coordinate (mouse) or 0 (keyboard)
    x: i32,
    /// Y coordinate (mouse) or 0 (keyboard)
    y: i32,
    /// Wheel delta (scroll) or virtual key code (keyboard)
    data: i32,
};

// ═══════════════════════════════════════════════════════════════════════
//  Recorder State
// ═══════════════════════════════════════════════════════════════════════

/// Thread-local pointer to active recorder for hook callbacks
var active_recorder: ?*Recorder = null;

/// Input event recorder with encapsulated state
pub const Recorder = struct {
    events: std.ArrayListUnmanaged(Event),
    allocator: std.mem.Allocator,
    recording: bool,
    start_time: u64,
    mouse_hook: ?win32.HHOOK,
    keyboard_hook: ?win32.HHOOK,
    hook_thread: ?win32.HANDLE,
    stop_thread: bool,

    /// Initialize a new recorder with the given allocator
    pub fn init(allocator: std.mem.Allocator) Recorder {
        return .{
            .events = .empty,
            .allocator = allocator,
            .recording = false,
            .start_time = 0,
            .mouse_hook = null,
            .keyboard_hook = null,
            .hook_thread = null,
            .stop_thread = false,
        };
    }

    /// Free all resources
    pub fn deinit(self: *Recorder) void {
        self.stopRecording();
        self.events.deinit(self.allocator);
    }

    /// Start recording input events
    /// Returns error if already recording or hook installation fails
    pub fn startRecording(self: *Recorder) errors.RecorderError!void {
        if (self.recording) return error.AlreadyRecording;

        self.events.clearRetainingCapacity();
        self.start_time = win32.GetTickCount64();
        self.stop_thread = false;

        // Set active recorder for hook callbacks
        active_recorder = self;
        self.recording = true;

        // Start hook thread
        self.hook_thread = win32.CreateThread(
            null,
            0,
            hookThreadProc,
            null,
            0,
            null,
        );

        if (self.hook_thread == null) {
            self.recording = false;
            active_recorder = null;
            return error.ThreadCreationFailed;
        }

        // Give the thread a moment to set up the hooks
        win32.Sleep(50);
    }

    /// Stop recording input events
    pub fn stopRecording(self: *Recorder) void {
        if (!self.recording) return;

        self.recording = false;
        self.stop_thread = true;

        // Wait for hook thread to finish
        if (self.hook_thread) |thread| {
            _ = win32.WaitForSingleObject(thread, 1000);
            self.hook_thread = null;
        }

        active_recorder = null;
    }

    /// Check if currently recording
    pub fn isRecording(self: *const Recorder) bool {
        return self.recording;
    }

    /// Get all recorded events
    pub fn getEvents(self: *const Recorder) []const Event {
        return self.events.items;
    }

    /// Get the number of recorded events
    pub fn getEventCount(self: *const Recorder) usize {
        return self.events.items.len;
    }

    /// Clear all recorded events
    pub fn clearEvents(self: *Recorder) void {
        self.events.clearRetainingCapacity();
    }

    /// Load events from a slice (used when loading from file)
    pub fn setEvents(self: *Recorder, new_events: []const Event) errors.RecorderError!void {
        self.events.clearRetainingCapacity();
        try self.events.appendSlice(self.allocator, new_events);
    }

    /// Append an event (called from hook callbacks)
    fn appendEvent(self: *Recorder, event: Event) void {
        self.events.append(self.allocator, event) catch {};
    }
};

// ═══════════════════════════════════════════════════════════════════════
//  Hook Callbacks
// ═══════════════════════════════════════════════════════════════════════

/// Low-level mouse hook callback
fn mouseHookProc(nCode: c_int, wParam: usize, lParam: isize) callconv(.winapi) isize {
    const rec = active_recorder orelse return win32.CallNextHookEx(null, nCode, wParam, lParam);
    
    if (nCode >= 0 and rec.recording) {
        const hook_struct: *align(1) const win32.MSLLHOOKSTRUCT = 
            @ptrFromInt(@as(usize, @bitCast(lParam)));
        const elapsed = win32.GetTickCount64() - rec.start_time;

        const event_type: ?EventType = switch (wParam) {
            win32.WM_MOUSEMOVE => .move,
            win32.WM_LBUTTONDOWN => .left_down,
            win32.WM_LBUTTONUP => .left_up,
            win32.WM_RBUTTONDOWN => .right_down,
            win32.WM_RBUTTONUP => .right_up,
            win32.WM_MOUSEWHEEL => .wheel,
            else => null,
        };

        if (event_type) |et| {
            // For wheel events, extract the wheel delta from mouseData high word
            const wheel_data: i32 = if (et == .wheel)
                @as(i16, @bitCast(@as(u16, @truncate(hook_struct.mouseData >> 16))))
            else
                0;

            rec.appendEvent(.{
                .timestamp_ms = @intCast(elapsed),
                .event_type = et,
                .x = @intCast(hook_struct.pt.x),
                .y = @intCast(hook_struct.pt.y),
                .data = wheel_data,
            });
        }
    }
    return win32.CallNextHookEx(rec.mouse_hook, nCode, wParam, lParam);
}

/// Low-level keyboard hook callback
fn keyboardHookProc(nCode: c_int, wParam: usize, lParam: isize) callconv(.winapi) isize {
    const rec = active_recorder orelse return win32.CallNextHookEx(null, nCode, wParam, lParam);
    
    if (nCode >= 0 and rec.recording) {
        const hook_struct: *align(1) const win32.KBDLLHOOKSTRUCT = 
            @ptrFromInt(@as(usize, @bitCast(lParam)));
        const elapsed = win32.GetTickCount64() - rec.start_time;

        const event_type: ?EventType = switch (wParam) {
            win32.WM_KEYDOWN, win32.WM_SYSKEYDOWN => .key_down,
            win32.WM_KEYUP, win32.WM_SYSKEYUP => .key_up,
            else => null,
        };

        if (event_type) |et| {
            rec.appendEvent(.{
                .timestamp_ms = @intCast(elapsed),
                .event_type = et,
                .x = 0,
                .y = 0,
                .data = @intCast(hook_struct.vkCode),
            });
        }
    }
    return win32.CallNextHookEx(rec.keyboard_hook, nCode, wParam, lParam);
}

/// Thread function that runs the message pump for the hooks
fn hookThreadProc(_: ?*anyopaque) callconv(.winapi) u32 {
    const rec = active_recorder orelse return 1;

    // Install the mouse hook
    rec.mouse_hook = win32.SetWindowsHookExW(win32.WH_MOUSE_LL, mouseHookProc, null, 0);
    // Install the keyboard hook
    rec.keyboard_hook = win32.SetWindowsHookExW(win32.WH_KEYBOARD_LL, keyboardHookProc, null, 0);

    if (rec.mouse_hook == null and rec.keyboard_hook == null) {
        return 1;
    }

    // Message pump loop
    var msg: win32.MSG = std.mem.zeroes(win32.MSG);
    while (!rec.stop_thread) {
        if (win32.PeekMessageW(&msg, null, 0, 0, win32.PM_REMOVE) != 0) {
            _ = win32.TranslateMessage(&msg);
            _ = win32.DispatchMessageW(&msg);
        } else {
            win32.Sleep(1);
        }
    }

    // Unhook when done
    if (rec.mouse_hook) |h| {
        _ = win32.UnhookWindowsHookEx(h);
        rec.mouse_hook = null;
    }
    if (rec.keyboard_hook) |h| {
        _ = win32.UnhookWindowsHookEx(h);
        rec.keyboard_hook = null;
    }

    return 0;
}

// ═══════════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════════

test "EventType.fromString parses valid strings" {
    try std.testing.expectEqual(EventType.move, EventType.fromString("move"));
    try std.testing.expectEqual(EventType.left_down, EventType.fromString("left_down"));
    try std.testing.expectEqual(EventType.key_up, EventType.fromString("key_up"));
}

test "EventType.fromString returns null for invalid strings" {
    try std.testing.expectEqual(@as(?EventType, null), EventType.fromString("invalid"));
    try std.testing.expectEqual(@as(?EventType, null), EventType.fromString(""));
}

test "EventType.toString matches tag name" {
    try std.testing.expectEqualStrings("move", EventType.move.toString());
    try std.testing.expectEqualStrings("key_down", EventType.key_down.toString());
}

test "Recorder init/deinit" {
    var rec = Recorder.init(std.testing.allocator);
    defer rec.deinit();
    
    try std.testing.expectEqual(@as(usize, 0), rec.getEventCount());
    try std.testing.expectEqual(false, rec.isRecording());
}

test "Recorder setEvents" {
    var rec = Recorder.init(std.testing.allocator);
    defer rec.deinit();
    
    const events = [_]Event{
        .{ .timestamp_ms = 0, .event_type = .move, .x = 100, .y = 200, .data = 0 },
        .{ .timestamp_ms = 100, .event_type = .left_down, .x = 100, .y = 200, .data = 0 },
    };
    
    try rec.setEvents(&events);
    try std.testing.expectEqual(@as(usize, 2), rec.getEventCount());
}
