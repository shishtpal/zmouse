//! Mouse event recording and playback
//! Captures system-level mouse events using Win32 low-level hooks

const std = @import("std");
const win32 = @import("win32.zig");

/// Types of mouse events that can be recorded
pub const EventType = enum {
    move,
    left_down,
    left_up,
    right_down,
    right_up,
    wheel,

    pub fn toString(self: EventType) []const u8 {
        return switch (self) {
            .move => "move",
            .left_down => "left_down",
            .left_up => "left_up",
            .right_down => "right_down",
            .right_up => "right_up",
            .wheel => "wheel",
        };
    }

    pub fn fromString(s: []const u8) ?EventType {
        if (std.mem.eql(u8, s, "move")) return .move;
        if (std.mem.eql(u8, s, "left_down")) return .left_down;
        if (std.mem.eql(u8, s, "left_up")) return .left_up;
        if (std.mem.eql(u8, s, "right_down")) return .right_down;
        if (std.mem.eql(u8, s, "right_up")) return .right_up;
        if (std.mem.eql(u8, s, "wheel")) return .wheel;
        return null;
    }
};

/// A single recorded mouse event
pub const MouseEvent = struct {
    timestamp_ms: i64, // Milliseconds since recording started
    event_type: EventType,
    x: i32,
    y: i32,
    data: i32, // For scroll amount (wheel delta)
};

/// Global recording state
var events: std.ArrayListUnmanaged(MouseEvent) = .empty;
var allocator: std.mem.Allocator = undefined;
var initialized: bool = false;
var recording: bool = false;
var start_time: u64 = 0;
var hook: ?win32.HHOOK = null;
var hook_thread: ?win32.HANDLE = null;
var stop_thread: bool = false;

/// Initialize the recorder with an allocator
pub fn init(alloc: std.mem.Allocator) void {
    if (initialized) return;
    allocator = alloc;
    events = .empty;
    initialized = true;
}

/// Deinitialize and free resources
pub fn deinit() void {
    if (!initialized) return;
    stopRecording();
    events.deinit(allocator);
    initialized = false;
}

/// Low-level mouse hook callback
fn mouseHookProc(nCode: c_int, wParam: usize, lParam: isize) callconv(.winapi) isize {
    if (nCode >= 0 and recording) {
        const hook_struct: *win32.MSLLHOOKSTRUCT = @ptrFromInt(@as(usize, @bitCast(lParam)));
        const elapsed = win32.GetTickCount64() - start_time;

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

            events.append(allocator, .{
                .timestamp_ms = @intCast(elapsed),
                .event_type = et,
                .x = @intCast(hook_struct.pt.x),
                .y = @intCast(hook_struct.pt.y),
                .data = wheel_data,
            }) catch {};
        }
    }
    return win32.CallNextHookEx(hook, nCode, wParam, lParam);
}

/// Thread function that runs the message pump for the hook
fn hookThreadProc(_: ?*anyopaque) callconv(.winapi) u32 {
    // Install the hook in this thread
    hook = win32.SetWindowsHookExW(win32.WH_MOUSE_LL, mouseHookProc, null, 0);
    if (hook == null) {
        return 1;
    }

    // Message pump loop
    var msg: win32.MSG = undefined;
    while (!stop_thread) {
        // Use GetMessage for blocking (more efficient) or PeekMessage for polling
        if (win32.PeekMessageW(&msg, null, 0, 0, win32.PM_REMOVE) != 0) {
            _ = win32.TranslateMessage(&msg);
            _ = win32.DispatchMessageW(&msg);
        } else {
            // Small sleep to avoid busy-waiting
            win32.Sleep(1);
        }
    }

    // Unhook when done
    if (hook) |h| {
        _ = win32.UnhookWindowsHookEx(h);
        hook = null;
    }

    return 0;
}

/// Start recording mouse events
pub fn startRecording() bool {
    if (!initialized or recording) return false;

    events.clearRetainingCapacity();
    start_time = win32.GetTickCount64();
    stop_thread = false;
    recording = true;

    // Start hook thread
    hook_thread = win32.CreateThread(
        null,
        0,
        hookThreadProc,
        null,
        0,
        null,
    );

    if (hook_thread == null) {
        recording = false;
        return false;
    }

    // Give the thread a moment to set up the hook
    win32.Sleep(50);

    return true;
}

/// Stop recording mouse events
pub fn stopRecording() void {
    if (!recording) return;
    
    recording = false;
    stop_thread = true;

    // Wait for hook thread to finish
    if (hook_thread) |thread| {
        _ = win32.WaitForSingleObject(thread, 1000); // Wait up to 1 second
        hook_thread = null;
    }
}

/// Check if currently recording
pub fn isRecording() bool {
    return recording;
}

/// Get the recorded events
pub fn getEvents() []const MouseEvent {
    if (!initialized) return &[_]MouseEvent{};
    return events.items;
}

/// Get event count
pub fn getEventCount() usize {
    if (!initialized) return 0;
    return events.items.len;
}

/// Clear all recorded events
pub fn clearEvents() void {
    if (!initialized) return;
    events.clearRetainingCapacity();
}

/// Set events (used when loading from file)
pub fn setEvents(new_events: []const MouseEvent) !void {
    if (!initialized) return error.NotInitialized;
    events.clearRetainingCapacity();
    try events.appendSlice(allocator, new_events);
}

pub const RecorderError = error{
    NotInitialized,
    OutOfMemory,
};
