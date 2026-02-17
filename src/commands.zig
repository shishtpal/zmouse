//! Command parsing and dispatch
//! Parses user input strings and executes corresponding mouse actions

const std = @import("std");
const mouse = @import("mouse.zig");

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

/// Parse and dispatch a single trimmed command string
pub fn runCommand(
    cmd: []const u8,
    sw: c_int,
    sh: c_int,
) !void {
    if (cmd.len == 0) return;

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
        \\  sc<N>      scroll up       sd<N>       scroll down
        \\  q          quit
        \\
        \\
    , .{ sw, sh });
}
