//! Command parsing and dispatch
//! Parses user input strings and executes corresponding input actions
//!
//! Commands:
//!   m<X>-<Y>   - Move mouse to coordinates
//!   c<X>-<Y>   - Move and left-click
//!   r<X>-<Y>   - Move and right-click
//!   d<X>-<Y>   - Move and double-click
//!   sc<N>      - Scroll up N units
//!   sd<N>      - Scroll down N units
//!   g          - Get mouse position
//!   rec        - Start recording
//!   stop       - Stop recording
//!   save <f>   - Save events to file
//!   load <f>   - Load events from file
//!   play       - Replay events

const std = @import("std");
const input = @import("mouse.zig");
const recorder = @import("recorder.zig");
const json_io = @import("json_io.zig");
const win32 = @import("win32.zig");
const errors = @import("errors.zig");

pub const CommandError = errors.CommandError;

// ═══════════════════════════════════════════════════════════════════════
//  Coordinate Parsing
// ═══════════════════════════════════════════════════════════════════════

const CoordinatePair = struct {
    x: i32,
    y: i32,
};

fn parseXY(s: []const u8) CommandError!CoordinatePair {
    const sep = std.mem.indexOfScalar(u8, s, '-') orelse
        return error.InvalidFormat;
    if (sep == 0 or sep >= s.len - 1)
        return error.InvalidFormat;
    return .{
        .x = std.fmt.parseInt(i32, s[0..sep], 10) catch
            return error.InvalidNumber,
        .y = std.fmt.parseInt(i32, s[sep + 1 ..], 10) catch
            return error.InvalidNumber,
    };
}

// ═══════════════════════════════════════════════════════════════════════
//  Command Handlers
// ═══════════════════════════════════════════════════════════════════════

fn executeMove(args: []const u8, screen: input.ScreenDimensions) !void {
    const pt = try parseXY(args);
    input.moveMouse(pt.x, pt.y, screen) catch return error.InvalidCoordinates;
    std.debug.print("  Mouse moved to ({d}, {d})\n\n", .{ pt.x, pt.y });
}

fn executeClick(args: []const u8, screen: input.ScreenDimensions) !void {
    const pt = try parseXY(args);
    input.moveMouse(pt.x, pt.y, screen) catch return error.InvalidCoordinates;
    input.leftClick();
    std.debug.print("  Mouse moved to ({d}, {d}) and clicked\n\n", .{ pt.x, pt.y });
}

fn executeRightClick(args: []const u8, screen: input.ScreenDimensions) !void {
    const pt = try parseXY(args);
    input.moveMouse(pt.x, pt.y, screen) catch return error.InvalidCoordinates;
    input.rightClick();
    std.debug.print("  Mouse moved to ({d}, {d}) and right-clicked\n\n", .{ pt.x, pt.y });
}

fn executeDoubleClick(args: []const u8, screen: input.ScreenDimensions) !void {
    const pt = try parseXY(args);
    input.moveMouse(pt.x, pt.y, screen) catch return error.InvalidCoordinates;
    input.doubleClick();
    std.debug.print("  Mouse moved to ({d}, {d}) and double-clicked\n\n", .{ pt.x, pt.y });
}

fn executeScrollUp(args: []const u8) !void {
    const n = std.fmt.parseInt(i32, args, 10) catch
        return error.InvalidNumber;
    input.scrollUp(n);
    std.debug.print("  Scrolled up by {d}\n\n", .{n});
}

fn executeScrollDown(args: []const u8) !void {
    const n = std.fmt.parseInt(i32, args, 10) catch
        return error.InvalidNumber;
    input.scrollDown(n);
    std.debug.print("  Scrolled down by {d}\n\n", .{n});
}

fn executeGetPosition() void {
    if (input.getPosition()) |pos| {
        std.debug.print("  Mouse position: ({d}, {d})\n\n", .{ pos.x, pos.y });
    } else {
        std.debug.print("  Error: Could not get mouse position\n\n", .{});
    }
}

fn executeStartRecording(rec: *recorder.Recorder) void {
    if (rec.isRecording()) {
        std.debug.print("  Already recording. Use 'stop' first.\n\n", .{});
        return;
    }
    rec.startRecording() catch {
        std.debug.print("  Error: Could not start recording.\n\n", .{});
        return;
    };
    std.debug.print("  Recording started. Use 'stop' to finish.\n\n", .{});
}

fn executeStopRecording(rec: *recorder.Recorder) void {
    if (!rec.isRecording()) {
        std.debug.print("  Not currently recording.\n\n", .{});
        return;
    }
    rec.stopRecording();
    std.debug.print("  Recording stopped. {d} events captured.\n\n", .{rec.getEventCount()});
}

fn executeSave(filename: []const u8, alloc: std.mem.Allocator, rec: *recorder.Recorder) void {
    const events = rec.getEvents();
    if (events.len == 0) {
        std.debug.print("  No events to save.\n\n", .{});
        return;
    }
    json_io.saveEvents(events, filename, alloc) catch |err| {
        std.debug.print("  Error saving: {}\n\n", .{err});
        return;
    };
    std.debug.print("  Saved {d} events to '{s}'\n\n", .{ events.len, filename });
}

fn executeLoad(filename: []const u8, alloc: std.mem.Allocator, rec: *recorder.Recorder) void {
    const events = json_io.loadEvents(filename, alloc) catch |err| {
        std.debug.print("  Error loading: {}\n\n", .{err});
        return;
    };
    defer alloc.free(events);

    rec.setEvents(events) catch {
        std.debug.print("  Error setting events.\n\n", .{});
        return;
    };
    std.debug.print("  Loaded {d} events from '{s}'\n\n", .{ rec.getEventCount(), filename });
}

fn executePlay(screen: input.ScreenDimensions, rec: *recorder.Recorder) void {
    const events = rec.getEvents();
    if (events.len == 0) {
        std.debug.print("  No events to play. Record or load first.\n\n", .{});
        return;
    }

    std.debug.print("  Playing {d} events...\n", .{events.len});

    var prev_time: i64 = 0;
    for (events) |event| {
        if (event.timestamp_ms > prev_time) {
            const delay: u32 = @intCast(event.timestamp_ms - prev_time);
            win32.Sleep(delay);
        }
        prev_time = event.timestamp_ms;

        switch (event.event_type) {
            .move => input.moveMouse(event.x, event.y, screen) catch {},
            .left_down => input.sendMouseEvent(win32.MOUSEEVENTF_LEFTDOWN),
            .left_up => input.sendMouseEvent(win32.MOUSEEVENTF_LEFTUP),
            .right_down => input.sendMouseEvent(win32.MOUSEEVENTF_RIGHTDOWN),
            .right_up => input.sendMouseEvent(win32.MOUSEEVENTF_RIGHTUP),
            .wheel => {
                const scroll_amount = @divTrunc(event.data, win32.WHEEL_DELTA);
                input.scrollWheel(scroll_amount);
            },
            .key_down => input.sendKey(@intCast(event.data), false),
            .key_up => input.sendKey(@intCast(event.data), true),
        }
    }

    std.debug.print("  Playback complete.\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════
//  Command Dispatcher
// ═══════════════════════════════════════════════════════════════════════

/// Parse and dispatch a single trimmed command string
pub fn runCommand(
    cmd: []const u8,
    sw: c_int,
    sh: c_int,
    alloc: std.mem.Allocator,
    rec: *recorder.Recorder,
) !void {
    if (cmd.len == 0) return;

    const screen = input.ScreenDimensions{ .width = sw, .height = sh };

    // Single-char commands
    if (std.mem.eql(u8, cmd, "g")) {
        executeGetPosition();
        return;
    }

    // Recording commands
    if (std.mem.eql(u8, cmd, "rec")) {
        executeStartRecording(rec);
        return;
    }
    if (std.mem.eql(u8, cmd, "stop")) {
        executeStopRecording(rec);
        return;
    }
    if (std.mem.eql(u8, cmd, "play")) {
        executePlay(screen, rec);
        return;
    }

    // Commands with arguments
    if (cmd.len >= 5 and std.mem.eql(u8, cmd[0..5], "save ")) {
        const filename = std.mem.trim(u8, cmd[5..], " \t");
        if (filename.len > 0) {
            executeSave(filename, alloc, rec);
            return;
        }
    }
    if (cmd.len >= 5 and std.mem.eql(u8, cmd[0..5], "load ")) {
        const filename = std.mem.trim(u8, cmd[5..], " \t");
        if (filename.len > 0) {
            executeLoad(filename, alloc, rec);
            return;
        }
    }

    // Scroll commands
    if (cmd.len >= 3) {
        if (std.mem.eql(u8, cmd[0..2], "sc")) {
            return executeScrollUp(cmd[2..]);
        }
        if (std.mem.eql(u8, cmd[0..2], "sd")) {
            return executeScrollDown(cmd[2..]);
        }
    }

    // Coordinate commands
    if (cmd.len < 4) return error.UnknownCommand;

    switch (cmd[0]) {
        'm' => try executeMove(cmd[1..], screen),
        'c' => try executeClick(cmd[1..], screen),
        'r' => try executeRightClick(cmd[1..], screen),
        'd' => try executeDoubleClick(cmd[1..], screen),
        else => return error.UnknownCommand,
    }
}

/// Print the help message
pub fn printHelp(sw: c_int, sh: c_int) void {
    std.debug.print(
        \\
        \\  ZMouse  (screen {d} x {d})
        \\  ─────────────────────────────────────
        \\  m<X>-<Y>   move            c<X>-<Y>   move + left-click
        \\  r<X>-<Y>   move + right    d<X>-<Y>   move + double-click
        \\  sc<N>      scroll up       sd<N>      scroll down
        \\  g          get position    q          quit
        \\
        \\  Recording:
        \\  rec           start recording input events
        \\  stop          stop recording
        \\  save <file>   save events to JSON file
        \\  load <file>   load events from JSON file
        \\  play          replay events
        \\
        \\
    , .{ sw, sh });
}
