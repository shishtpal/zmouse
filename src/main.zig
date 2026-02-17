//! Mouse Controller - Entry point and REPL loop
//!
//! Build:  zig build
//! Run:    zig build run
//!
//! Requires Windows – uses user32.dll via Zig C-interop.

const std = @import("std");
const win32 = @import("win32.zig");
const commands = @import("commands.zig");

/// Read a line from stdin (strips \r and \n)
fn readLine(reader: *std.Io.File.Reader, buf: []u8) !?[]const u8 {
    var len: usize = 0;

    while (len < buf.len) {
        const byte_slice = reader.interface.take(1) catch |err| {
            if (err == error.EndOfStream) {
                return if (len > 0) buf[0..len] else null;
            }
            return err;
        };
        const byte = byte_slice[0];
        if (byte == '\n') break;
        if (byte == '\r') continue;
        buf[len] = byte;
        len += 1;
    }

    return buf[0..len];
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // Grab primary-monitor resolution for absolute-coordinate mapping.
    const screen_width = win32.GetSystemMetrics(win32.SM_CXSCREEN);
    const screen_height = win32.GetSystemMetrics(win32.SM_CYSCREEN);

    if (screen_width <= 1 or screen_height <= 1) {
        std.debug.print("Error: cannot retrieve valid screen dimensions.\n", .{});
        return;
    }

    // Print help banner
    std.debug.print(
        \\
        \\  Mouse Controller  (screen {d} x {d})
        \\  ---------------------------------------------------------
        \\  m<X>-<Y>   move            c<X>-<Y>   move + left-click
        \\  r<X>-<Y>   move + right    d<X>-<Y>   move + double-click
        \\  sc<N>      scroll up       sd<N>       scroll down
        \\  q          quit
        \\
        \\
    , .{ screen_width, screen_height });

    // Set up stdin reader
    const stdin_file = std.Io.File.stdin();
    var read_buf: [4096]u8 = undefined;
    var reader = std.Io.File.Reader.init(stdin_file, io, &read_buf);

    var line_buf: [256]u8 = undefined;

    while (true) {
        std.debug.print("> ", .{});

        const line_opt = readLine(&reader, &line_buf) catch {
            std.debug.print("  Error: could not read input.\n\n", .{});
            continue;
        };

        const line = line_opt orelse break; // EOF → exit gracefully

        // Strip surrounding whitespace
        const cmd = std.mem.trim(u8, line, " \t");

        if (cmd.len == 0) continue;

        if (std.mem.eql(u8, cmd, "q")) {
            std.debug.print("  Exiting...\n", .{});
            break;
        }

        commands.runCommand(cmd, screen_width, screen_height) catch {
            std.debug.print("  Error: Unknown command format\n\n", .{});
        };
    }
}
