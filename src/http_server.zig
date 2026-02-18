//! Minimal HTTP server for API endpoints
//! Uses Win32 sockets directly (no external dependencies)

const std = @import("std");
const win32 = @import("win32.zig");
const mouse = @import("mouse.zig");
const recorder = @import("recorder.zig");
const json_io = @import("json_io.zig");
const screenshot = @import("screenshot.zig");

var server_socket: win32.SOCKET = win32.INVALID_SOCKET;
var running: bool = false;
var server_allocator: std.mem.Allocator = undefined;
var screen_width: c_int = 0;
var screen_height: c_int = 0;

/// Initialize and start the HTTP server
pub fn start(port: u16, alloc: std.mem.Allocator, sw: c_int, sh: c_int) bool {
    server_allocator = alloc;
    screen_width = sw;
    screen_height = sh;

    // Initialize Winsock
    var wsa_data: win32.WSAData = undefined;
    if (win32.WSAStartup(0x0202, &wsa_data) != 0) {
        return false;
    }

    // Create socket
    server_socket = win32.socket(win32.AF_INET, win32.SOCK_STREAM, win32.IPPROTO_TCP);
    if (server_socket == win32.INVALID_SOCKET) {
        _ = win32.WSACleanup();
        return false;
    }

    // Bind to port
    var addr: win32.SOCKADDR_IN = .{
        .sin_family = @intCast(win32.AF_INET),
        .sin_port = std.mem.nativeToBig(u16, port),
        .sin_addr = 0, // INADDR_ANY (0.0.0.0)
        .sin_zero = .{0} ** 8,
    };

    if (win32.bind(server_socket, &addr, @sizeOf(win32.SOCKADDR_IN)) != 0) {
        _ = win32.closesocket(server_socket);
        _ = win32.WSACleanup();
        return false;
    }

    // Listen
    if (win32.listen(server_socket, 5) != 0) {
        _ = win32.closesocket(server_socket);
        _ = win32.WSACleanup();
        return false;
    }

    // Set non-blocking mode
    var mode: u32 = 1;
    _ = win32.ioctlsocket(server_socket, win32.FIONBIO, &mode);

    running = true;
    return true;
}

/// Stop the HTTP server
pub fn stop() void {
    running = false;
    if (server_socket != win32.INVALID_SOCKET) {
        _ = win32.closesocket(server_socket);
        server_socket = win32.INVALID_SOCKET;
    }
    _ = win32.WSACleanup();
}

/// Check if server is running
pub fn isRunning() bool {
    return running;
}

/// Process incoming connections (call periodically)
pub fn poll() void {
    if (!running) return;

    // Accept new connection
    var client_addr: win32.SOCKADDR_IN = undefined;
    var client_addr_len: i32 = @sizeOf(win32.SOCKADDR_IN);

    const client = win32.accept(server_socket, &client_addr, &client_addr_len);
    if (client == win32.INVALID_SOCKET) return;

    // Read request
    var buf: [4096]u8 = undefined;
    const received = win32.recv(client, &buf, @intCast(buf.len), 0);
    if (received <= 0) {
        _ = win32.closesocket(client);
        return;
    }

    const request = buf[0..@as(usize, @intCast(received))];

    // Parse and handle request
    handleRequest(client, request) catch {
        sendError(client, 500, "Internal Server Error");
    };

    _ = win32.closesocket(client);
}

/// HTTP request handling
fn handleRequest(client: win32.SOCKET, request: []const u8) !void {
    // Parse request line
    const line_end = std.mem.indexOf(u8, request, "\r\n") orelse return error.InvalidRequest;
    const request_line = request[0..line_end];

    // Parse method and path
    var parts = std.mem.splitSequence(u8, request_line, " ");
    const method = parts.next() orelse return error.InvalidRequest;
    const path_query = parts.next() orelse return error.InvalidRequest;

    // Split path and query string
    const query_start = std.mem.indexOf(u8, path_query, "?");
    const path = if (query_start) |qs| path_query[0..qs] else path_query;
    const query = if (query_start) |qs| path_query[qs + 1 ..] else "";

    // Find body (after double CRLF)
    const body_start = std.mem.indexOf(u8, request, "\r\n\r\n");
    const body = if (body_start) |bs| request[bs + 4 ..] else "";

    // Route to handler
    if (std.mem.eql(u8, path, "/")) {
        sendJson(client, 200, "{\"name\":\"zmouse\",\"version\":\"1.0\"}");
    } else if (std.mem.eql(u8, path, "/api/position")) {
        handleGetPosition(client);
    } else if (std.mem.eql(u8, path, "/api/move")) {
        if (std.mem.eql(u8, method, "POST"))
            handleMove(client, body)
        else
            sendError(client, 405, "Method Not Allowed");
    } else if (std.mem.eql(u8, path, "/api/click")) {
        if (std.mem.eql(u8, method, "POST"))
            handleClick(client, body)
        else
            sendError(client, 405, "Method Not Allowed");
    } else if (std.mem.eql(u8, path, "/api/scroll")) {
        if (std.mem.eql(u8, method, "POST"))
            handleScroll(client, body)
        else
            sendError(client, 405, "Method Not Allowed");
    } else if (std.mem.eql(u8, path, "/api/keyboard")) {
        if (std.mem.eql(u8, method, "POST"))
            handleKeyboard(client, body)
        else
            sendError(client, 405, "Method Not Allowed");
    } else if (std.mem.eql(u8, path, "/api/screenshot")) {
        handleScreenshot(client, query);
    } else if (std.mem.eql(u8, path, "/api/recording/status")) {
        handleRecordingStatus(client);
    } else if (std.mem.eql(u8, path, "/api/recording/start")) {
        if (std.mem.eql(u8, method, "POST"))
            handleRecordingStart(client)
        else
            sendError(client, 405, "Method Not Allowed");
    } else if (std.mem.eql(u8, path, "/api/recording/stop")) {
        if (std.mem.eql(u8, method, "POST"))
            handleRecordingStop(client)
        else
            sendError(client, 405, "Method Not Allowed");
    } else if (std.mem.eql(u8, path, "/api/recording/save")) {
        if (std.mem.eql(u8, method, "POST"))
            handleRecordingSave(client, body)
        else
            sendError(client, 405, "Method Not Allowed");
    } else if (std.mem.eql(u8, path, "/api/recording/load")) {
        if (std.mem.eql(u8, method, "POST"))
            handleRecordingLoad(client, body)
        else
            sendError(client, 405, "Method Not Allowed");
    } else if (std.mem.eql(u8, path, "/api/recording/play")) {
        if (std.mem.eql(u8, method, "POST"))
            handleRecordingPlay(client)
        else
            sendError(client, 405, "Method Not Allowed");
    } else {
        sendError(client, 404, "Not Found");
    }
}

// ═══════════════════════════════════════════════════════════════════════
//  Route handlers
// ═══════════════════════════════════════════════════════════════════════

fn handleGetPosition(client: win32.SOCKET) void {
    if (mouse.getPosition()) |pos| {
        var buf: [128]u8 = undefined;
        const json = std.fmt.bufPrint(&buf, "{{\"x\":{d},\"y\":{d}}}", .{ pos.x, pos.y }) catch return;
        sendJson(client, 200, json);
    } else {
        sendError(client, 500, "Could not get position");
    }
}

fn handleMove(client: win32.SOCKET, body: []const u8) void {
    const x = parseJsonInt(body, "x") orelse return sendError(client, 400, "Missing x");
    const y = parseJsonInt(body, "y") orelse return sendError(client, 400, "Missing y");

    mouse.moveMouse(x, y, screen_width, screen_height);
    sendJson(client, 200, "{\"ok\":true}");
}

fn handleClick(client: win32.SOCKET, body: []const u8) void {
    const x = parseJsonInt(body, "x") orelse return sendError(client, 400, "Missing x");
    const y = parseJsonInt(body, "y") orelse return sendError(client, 400, "Missing y");
    const button = parseJsonString(body, "button") orelse "left";

    mouse.moveMouse(x, y, screen_width, screen_height);

    if (std.mem.eql(u8, button, "right")) {
        mouse.rightClick();
    } else if (std.mem.eql(u8, button, "double")) {
        mouse.doubleClick();
    } else {
        mouse.leftClick();
    }

    sendJson(client, 200, "{\"ok\":true}");
}

fn handleScroll(client: win32.SOCKET, body: []const u8) void {
    const amount = parseJsonInt(body, "amount") orelse return sendError(client, 400, "Missing amount");
    const direction = parseJsonString(body, "direction") orelse "up";

    const scroll_amount = if (std.mem.eql(u8, direction, "down")) -amount else amount;
    mouse.scrollWheel(scroll_amount);

    sendJson(client, 200, "{\"ok\":true}");
}

fn handleKeyboard(client: win32.SOCKET, body: []const u8) void {
    const key = parseJsonInt(body, "key") orelse return sendError(client, 400, "Missing key");
    const action = parseJsonString(body, "action") orelse "press";

    if (std.mem.eql(u8, action, "down")) {
        mouse.sendKey(@intCast(key), false);
    } else if (std.mem.eql(u8, action, "up")) {
        mouse.sendKey(@intCast(key), true);
    } else {
        // press = down + up
        mouse.sendKey(@intCast(key), false);
        mouse.sendKey(@intCast(key), true);
    }

    sendJson(client, 200, "{\"ok\":true}");
}

fn handleScreenshot(client: win32.SOCKET, query: []const u8) void {
    var shot = screenshot.captureScreen(server_allocator) orelse {
        sendError(client, 500, "Could not capture screen");
        return;
    };
    defer shot.deinit();

    // Check if base64 requested
    if (std.mem.indexOf(u8, query, "base64") != null) {
        const bmp_data = screenshot.encodeBmp(&shot, server_allocator) orelse {
            sendError(client, 500, "Could not encode BMP");
            return;
        };
        defer server_allocator.free(bmp_data);

        const b64 = screenshot.encodeBase64(bmp_data, server_allocator) catch {
            sendError(client, 500, "Could not encode base64");
            return;
        };
        defer server_allocator.free(b64);

        var buf: [1024]u8 = undefined;
        const json = std.fmt.bufPrint(&buf, "{{\"image\":\"{s}\"}}", .{b64}) catch return;
        sendJson(client, 200, json);
    } else {
        // Send as binary BMP
        const bmp_data = screenshot.encodeBmp(&shot, server_allocator) orelse {
            sendError(client, 500, "Could not encode BMP");
            return;
        };
        defer server_allocator.free(bmp_data);

        sendBinary(client, "image/bmp", bmp_data);
    }
}

fn handleRecordingStatus(client: win32.SOCKET) void {
    var buf: [128]u8 = undefined;
    const json = std.fmt.bufPrint(&buf, "{{\"recording\":{},\"events\":{d}}}", .{
        recorder.isRecording(),
        recorder.getEventCount(),
    }) catch return;
    sendJson(client, 200, json);
}

fn handleRecordingStart(client: win32.SOCKET) void {
    if (recorder.startRecording()) {
        sendJson(client, 200, "{\"ok\":true}");
    } else {
        sendError(client, 500, "Could not start recording");
    }
}

fn handleRecordingStop(client: win32.SOCKET) void {
    recorder.stopRecording();
    var buf: [128]u8 = undefined;
    const json = std.fmt.bufPrint(&buf, "{{\"ok\":true,\"events\":{d}}}", .{recorder.getEventCount()}) catch return;
    sendJson(client, 200, json);
}

fn handleRecordingSave(client: win32.SOCKET, body: []const u8) void {
    const filename = parseJsonString(body, "filename") orelse return sendError(client, 400, "Missing filename");

    const events = recorder.getEvents();
    json_io.saveEvents(events, filename, server_allocator) catch {
        sendError(client, 500, "Could not save");
        return;
    };

    var buf: [256]u8 = undefined;
    const json = std.fmt.bufPrint(&buf, "{{\"ok\":true,\"events\":{d}}}", .{events.len}) catch return;
    sendJson(client, 200, json);
}

fn handleRecordingLoad(client: win32.SOCKET, body: []const u8) void {
    const filename = parseJsonString(body, "filename") orelse return sendError(client, 400, "Missing filename");

    const events = json_io.loadEvents(filename, server_allocator) catch {
        sendError(client, 500, "Could not load");
        return;
    };
    defer server_allocator.free(events);

    recorder.setEvents(events) catch {
        sendError(client, 500, "Could not set events");
        return;
    };

    var buf: [256]u8 = undefined;
    const json = std.fmt.bufPrint(&buf, "{{\"ok\":true,\"events\":{d}}}", .{events.len}) catch return;
    sendJson(client, 200, json);
}

fn handleRecordingPlay(client: win32.SOCKET) void {
    const events = recorder.getEvents();
    if (events.len == 0) {
        sendError(client, 400, "No events to play");
        return;
    }

    // Play events (this blocks, but for simplicity we do it here)
    var prev_time: i64 = 0;
    for (events) |event| {
        if (event.timestamp_ms > prev_time) {
            const delay: u32 = @intCast(event.timestamp_ms - prev_time);
            win32.Sleep(delay);
        }
        prev_time = event.timestamp_ms;

        switch (event.event_type) {
            .move => mouse.moveMouse(event.x, event.y, screen_width, screen_height),
            .left_down => mouse.clickButton(win32.MOUSEEVENTF_LEFTDOWN, 0),
            .left_up => mouse.clickButton(0, win32.MOUSEEVENTF_LEFTUP),
            .right_down => mouse.clickButton(win32.MOUSEEVENTF_RIGHTDOWN, 0),
            .right_up => mouse.clickButton(0, win32.MOUSEEVENTF_RIGHTUP),
            .wheel => {
                const scroll_amount = @divTrunc(event.data, win32.WHEEL_DELTA);
                mouse.scrollWheel(scroll_amount);
            },
            .key_down => mouse.sendKey(@intCast(event.data), false),
            .key_up => mouse.sendKey(@intCast(event.data), true),
        }
    }

    sendJson(client, 200, "{\"ok\":true}");
}

// ═══════════════════════════════════════════════════════════════════════
//  HTTP response helpers
// ═══════════════════════════════════════════════════════════════════════

fn sendJson(client: win32.SOCKET, status: u16, body: []const u8) void {
    var buf: [1024]u8 = undefined;
    const response = std.fmt.bufPrint(&buf,
        "HTTP/1.1 {d} OK\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Content-Length: {d}\r\n" ++
        "Access-Control-Allow-Origin: *\r\n" ++
        "\r\n" ++
        "{s}",
        .{ status, body.len, body },
    ) catch return;

    _ = win32.send(client, response.ptr, @intCast(response.len), 0);
}

fn sendBinary(client: win32.SOCKET, content_type: []const u8, data: []const u8) void {
    var header_buf: [512]u8 = undefined;
    const header = std.fmt.bufPrint(&header_buf,
        "HTTP/1.1 200 OK\r\n" ++
        "Content-Type: {s}\r\n" ++
        "Content-Length: {d}\r\n" ++
        "Access-Control-Allow-Origin: *\r\n" ++
        "\r\n",
        .{ content_type, data.len },
    ) catch return;

    _ = win32.send(client, header.ptr, @intCast(header.len), 0);
    _ = win32.send(client, data.ptr, @intCast(data.len), 0);
}

fn sendError(client: win32.SOCKET, status: u16, message: []const u8) void {
    var buf: [512]u8 = undefined;
    var body_buf: [256]u8 = undefined;
    const body = std.fmt.bufPrint(&body_buf, "{{\"error\":\"{s}\"}}", .{message}) catch return;
    const response = std.fmt.bufPrint(&buf,
        "HTTP/1.1 {d} Error\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Content-Length: {d}\r\n" ++
        "Access-Control-Allow-Origin: *\r\n" ++
        "\r\n" ++
        "{s}",
        .{ status, body.len, body },
    ) catch return;

    _ = win32.send(client, response.ptr, @intCast(response.len), 0);
}

// ═══════════════════════════════════════════════════════════════════════
//  JSON parsing helpers (simple, no external deps)
// ═══════════════════════════════════════════════════════════════════════

fn parseJsonInt(body: []const u8, key: []const u8) ?i32 {
    var search_buf: [64]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":", .{key}) catch return null;
    const key_pos = std.mem.indexOf(u8, body, search) orelse return null;
    const val_start = key_pos + search.len;

    var end = val_start;
    while (end < body.len and ((body[end] >= '0' and body[end] <= '9') or body[end] == '-')) {
        end += 1;
    }

    if (end == val_start) return null;
    return std.fmt.parseInt(i32, body[val_start..end], 10) catch null;
}

fn parseJsonString(body: []const u8, key: []const u8) ?[]const u8 {
    var search_buf: [64]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":\"", .{key}) catch return null;
    const key_pos = std.mem.indexOf(u8, body, search) orelse return null;
    const val_start = key_pos + search.len;

    const end = std.mem.indexOfPos(u8, body, val_start, "\"") orelse return null;
    return body[val_start..end];
}
