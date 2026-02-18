//! Command parsing and dispatch
//! Parses user input strings and executes corresponding mouse actions

const std = @import("std");
const mouse = @import("mouse.zig");
const recorder = @import("recorder.zig");
const json_io = @import("json_io.zig");
const win32 = @import("win32.zig");

pub const CommandError = error{InvalidCommand};

/// Parsed coordinate command
const CoordinatePair = struct {
    x: i32,
    y: i32,
};

/// Parse the "X-Y" portion of a coordinate command (e.g. "120-150").
fn parseXY(s: []const u8) CommandError!CoordinatePair {
    const sep = std.mem.indexOfScalar(u8, s, '-') orelse
        return error.InvalidCommand;
    if (sep == 0 or sep >= s.len - 1)
        return error.InvalidCommand;
    return .{
        .x = std.fmt.parseInt(i32, s[0..sep], 10) catch
            return error.InvalidCommand,
        .y = std.fmt.parseInt(i32, s[sep + 1 ..], 10) catch
            return error.InvalidCommand,
    };
}

/// Execute a mouse movement command (m<X>-<Y>)
fn executeMove(args: []const u8, sw: c_int, sh: c_int) !void {
    const pt = try parseXY(args);
    mouse.moveMouse(pt.x, pt.y, sw, sh);
    std.debug.print("  Mouse moved to ({d}, {d})\n\n", .{ pt.x, pt.y });
}

/// Execute a click command (c<X>-<Y>)
fn executeClick(args: []const u8, sw: c_int, sh: c_int) !void {
    const pt = try parseXY(args);
    mouse.moveMouse(pt.x, pt.y, sw, sh);
    mouse.leftClick();
    std.debug.print("  Mouse moved to ({d}, {d}) and clicked\n\n", .{ pt.x, pt.y });
}

/// Execute a right-click command (r<X>-<Y>)
fn executeRightClick(args: []const u8, sw: c_int, sh: c_int) !void {
    const pt = try parseXY(args);
    mouse.moveMouse(pt.x, pt.y, sw, sh);
    mouse.rightClick();
    std.debug.print("  Mouse moved to ({d}, {d}) and right-clicked\n\n", .{ pt.x, pt.y });
}

/// Execute a double-click command (d<X>-<Y>)
fn executeDoubleClick(args: []const u8, sw: c_int, sh: c_int) !void {
    const pt = try parseXY(args);
    mouse.moveMouse(pt.x, pt.y, sw, sh);
    mouse.doubleClick();
    std.debug.print("  Mouse moved to ({d}, {d}) and double-clicked\n\n", .{ pt.x, pt.y });
}

/// Execute a scroll-up command (sc<N>)
fn executeScrollUp(args: []const u8) !void {
    const n = std.fmt.parseInt(i32, args, 10) catch
        return error.InvalidCommand;
    mouse.scrollWheel(n);
    std.debug.print("  Scrolled up by {d}\n\n", .{n});
}

/// Execute a scroll-down command (sd<N>)
fn executeScrollDown(args: []const u8) !void {
    const n = std.fmt.parseInt(i32, args, 10) catch
        return error.InvalidCommand;
    mouse.scrollWheel(-n);
    std.debug.print("  Scrolled down by {d}\n\n", .{n});
}

/// Execute a get-position command (g)
fn executeGetPosition() void {
    if (mouse.getPosition()) |pos| {
        std.debug.print("  Mouse position: ({d}, {d})\n\n", .{ pos.x, pos.y });
    } else {
        std.debug.print("  Error: Could not get mouse position\n\n", .{});
    }
}

/// Execute start recording command (rec)
fn executeStartRecording() void {
    if (recorder.isRecording()) {
        std.debug.print("  Already recording. Use 'stop' first.\n\n", .{});
        return;
    }
    if (recorder.startRecording()) {
        std.debug.print("  Recording started. Use 'stop' to finish.\n\n", .{});
    } else {
        std.debug.print("  Error: Could not start recording.\n\n", .{});
    }
}

/// Execute stop recording command (stop)
fn executeStopRecording() void {
    if (!recorder.isRecording()) {
        std.debug.print("  Not currently recording.\n\n", .{});
        return;
    }
    recorder.stopRecording();
    const count = recorder.getEventCount();
    std.debug.print("  Recording stopped. {d} events captured.\n\n", .{count});
}

/// Execute save command (save <filename>)
fn executeSave(filename: []const u8, alloc: std.mem.Allocator) void {
    const events = recorder.getEvents();
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

/// Execute load command (load <filename>)
fn executeLoad(filename: []const u8, alloc: std.mem.Allocator) void {
    const events = json_io.loadEvents(filename, alloc) catch |err| {
        std.debug.print("  Error loading: {}\n\n", .{err});
        return;
    };
    recorder.setEvents(events) catch |err| {
        alloc.free(events);
        std.debug.print("  Error setting events: {}\n\n", .{err});
        return;
    };
    alloc.free(events);
    std.debug.print("  Loaded {d} events from '{s}'\n\n", .{ recorder.getEventCount(), filename });
}

/// Execute play command (play)
fn executePlay(sw: c_int, sh: c_int) void {
    const events = recorder.getEvents();
    if (events.len == 0) {
        std.debug.print("  No events to play. Record or load first.\n\n", .{});
        return;
    }

    std.debug.print("  Playing {d} events...\n", .{events.len});

    var prev_time: i64 = 0;
    for (events) |event| {
        // Wait for the appropriate delay
        if (event.timestamp_ms > prev_time) {
            const delay: u32 = @intCast(event.timestamp_ms - prev_time);
            win32.Sleep(delay);
        }
        prev_time = event.timestamp_ms;

        // Execute the event
        switch (event.event_type) {
            .move => mouse.moveMouse(event.x, event.y, sw, sh),
            .left_down => mouse.clickButton(win32.MOUSEEVENTF_LEFTDOWN, 0),
            .left_up => mouse.clickButton(0, win32.MOUSEEVENTF_LEFTUP),
            .right_down => mouse.clickButton(win32.MOUSEEVENTF_RIGHTDOWN, 0),
            .right_up => mouse.clickButton(0, win32.MOUSEEVENTF_RIGHTUP),
            .wheel => {
                // Scroll amount is in data field (already multiplied by WHEEL_DELTA in original)
                const scroll_amount = @divTrunc(event.data, win32.WHEEL_DELTA);
                mouse.scrollWheel(scroll_amount);
            },
        }
    }

    std.debug.print("  Playback complete.\n\n", .{});
}

/// Parse and dispatch a single trimmed command string
pub fn runCommand(
    cmd: []const u8,
    sw: c_int,
    sh: c_int,
    alloc: std.mem.Allocator,
) !void {
    if (cmd.len == 0) return;

    // Single-char commands
    if (std.mem.eql(u8, cmd, "g")) {
        executeGetPosition();
        return;
    }

    // Recording commands
    if (std.mem.eql(u8, cmd, "rec")) {
        executeStartRecording();
        return;
    }
    if (std.mem.eql(u8, cmd, "stop")) {
        executeStopRecording();
        return;
    }
    if (std.mem.eql(u8, cmd, "play")) {
        executePlay(sw, sh);
        return;
    }

    // Commands with arguments
    if (cmd.len >= 5 and std.mem.eql(u8, cmd[0..5], "save ")) {
        const filename = std.mem.trim(u8, cmd[5..], " \t");
        if (filename.len > 0) {
            executeSave(filename, alloc);
            return;
        }
    }
    if (cmd.len >= 5 and std.mem.eql(u8, cmd[0..5], "load ")) {
        const filename = std.mem.trim(u8, cmd[5..], " \t");
        if (filename.len > 0) {
            executeLoad(filename, alloc);
            return;
        }
    }

    // Scroll commands (require at least 3 chars: "sc" or "sd" + digits)
    if (cmd.len >= 3) {
        if (std.mem.eql(u8, cmd[0..2], "sc")) {
            return executeScrollUp(cmd[2..]);
        }
        if (std.mem.eql(u8, cmd[0..2], "sd")) {
            return executeScrollDown(cmd[2..]);
        }
    }

    // Coordinate commands require at least 4 chars: letter + "X-Y"
    if (cmd.len < 4) return error.InvalidCommand;

    switch (cmd[0]) {
        'm' => try executeMove(cmd[1..], sw, sh),
        'c' => try executeClick(cmd[1..], sw, sh),
        'r' => try executeRightClick(cmd[1..], sw, sh),
        'd' => try executeDoubleClick(cmd[1..], sw, sh),
        else => return error.InvalidCommand,
    }
}

/// Print the help message
pub fn printHelp(sw: c_int, sh: c_int) void {
    std.debug.print(
        \\
        \\  Mouse Controller  (screen {d} x {d})
        \\  ─────────────────────────────────────
        \\  m<X>-<Y>   move            c<X>-<Y>   move + left-click
        \\  r<X>-<Y>   move + right    d<X>-<Y>   move + double-click
        \\  sc<N>      scroll up       sd<N>      scroll down
        \\  g          get position    q          quit
        \\
        \\  Recording:
        \\  rec           start recording mouse events
        \\  stop          stop recording
        \\  save <file>   save events to JSON file
        \\  load <file>   load events from JSON file
        \\  play          replay events
        \\
        \\
    , .{ sw, sh });
}
