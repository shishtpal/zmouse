//! ZMouse - Entry point and REPL loop
//!
//! Build:  zig build
//! Run:    zig build run
//! HTTP:   zig build run -- --http [port]
//! Test:   zig build test
//! Docs:   zig build docs
//!
//! Requires Windows – uses user32.dll, gdi32.dll, ws2_32.dll via Zig C-interop.

const std = @import("std");
const input = @import("mouse.zig");
const recorder = @import("recorder.zig");
const http_server = @import("http_server.zig");
const commands = @import("commands.zig");

const DEFAULT_HTTP_PORT: u16 = 4000;
const VERSION_MAJOR: u32 = 1;
const VERSION_MINOR: u32 = 0;

// ═══════════════════════════════════════════════════════════════════════
//  Command-Line Arguments
// ═══════════════════════════════════════════════════════════════════════

const ArgsResult = struct { http_port: ?u16 };

fn parseArgs(args: []const []const u8) ArgsResult {
    var result: ArgsResult = .{ .http_port = null };

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--http")) {
            if (i + 1 < args.len) {
                const next = args[i + 1];
                if (std.fmt.parseInt(u16, next, 10)) |port| {
                    result.http_port = port;
                    i += 1;
                } else |_| {
                    result.http_port = DEFAULT_HTTP_PORT;
                }
            } else {
                result.http_port = DEFAULT_HTTP_PORT;
            }
        }
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════
//  REPL
// ═══════════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════════
//  Main
// ═══════════════════════════════════════════════════════════════════════

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc = init.gpa;

    // Parse command-line arguments
    var args_buf: [256][]const u8 = undefined;
    var args_count: usize = 0;

    var arg_iter = try std.process.Args.Iterator.initAllocator(init.minimal.args, alloc);
    defer arg_iter.deinit();

    _ = arg_iter.skip();
    while (arg_iter.next()) |arg| {
        if (args_count >= args_buf.len) break;
        args_buf[args_count] = arg;
        args_count += 1;
    }
    const args = args_buf[0..args_count];

    const parsed = parseArgs(args);

    // Get screen dimensions
    const screen = input.getScreenDimensions() catch {
        std.debug.print("Error: cannot retrieve valid screen dimensions.\n", .{});
        return;
    };

    // Initialize recorder
    var rec = recorder.Recorder.init(alloc);
    defer rec.deinit();

    // Initialize HTTP server if requested
    var server = http_server.Server.init(alloc, screen.width, screen.height, &rec);
    defer server.deinit();

    if (parsed.http_port) |port| {
        server.start(port) catch {
            std.debug.print("Error: Could not start HTTP server on port {d}\n", .{port});
            return;
        };
        std.debug.print("HTTP server started on port {d}\n", .{port});
        std.debug.print("API endpoints: /api/position, /api/move, /api/click, /api/screenshot, etc.\n", .{});
    }

    // Print help banner
    printHelp(screen.width, screen.height);

    // Set up stdin reader
    const stdin_file = std.Io.File.stdin();
    var read_buf: [4096]u8 = undefined;
    var reader = std.Io.File.Reader.init(stdin_file, io, &read_buf);

    var line_buf: [256]u8 = undefined;

    while (true) {
        // Poll HTTP server
        if (server.isRunning()) {
            server.poll();
        }

        std.debug.print("> ", .{});

        const line_opt = readLine(&reader, &line_buf) catch {
            std.debug.print("  Error: could not read input.\n\n", .{});
            continue;
        };

        const line = line_opt orelse break;
        const cmd = std.mem.trim(u8, line, " \t");

        if (cmd.len == 0) continue;

        if (std.mem.eql(u8, cmd, "q")) {
            std.debug.print("  Exiting...\n", .{});
            break;
        }

        commands.runCommand(cmd, screen.width, screen.height, alloc, &rec) catch {
            std.debug.print("  Error: Unknown command format\n\n", .{});
        };
    }
}

fn printHelp(sw: c_int, sh: c_int) void {
    std.debug.print(
        \\
        \\  ZMouse v{d}.{d}  (screen {d} x {d})
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
    , .{ VERSION_MAJOR, VERSION_MINOR, sw, sh });
}
