//! HTTP server for API endpoints
//! Uses Win32 sockets directly (no external dependencies)
//!
//! Example usage:
//! ```zig
//! var server = Server.init(allocator, screen_width, screen_height, &rec);
//! defer server.deinit();
//!
//! try server.start(4000);
//! while (running) {
//!     server.poll();
//!     // ... do other work ...
//! }
//! server.stop();
//! ```

const std = @import("std");
const win32 = @import("win32.zig");
const mouse = @import("mouse.zig");
const recorder = @import("recorder.zig");
const json_io = @import("json_io.zig");
const screenshot = @import("screenshot.zig");
const errors = @import("errors.zig");

// ═══════════════════════════════════════════════════════════════════════
//  HTTP Server
// ═══════════════════════════════════════════════════════════════════════

/// HTTP server with encapsulated state
pub const Server = struct {
    socket: win32.SOCKET,
    allocator: std.mem.Allocator,
    screen: mouse.ScreenDimensions,
    running: bool,
    rec: *recorder.Recorder,

    /// Initialize a new server
    pub fn init(allocator: std.mem.Allocator, screen_width: c_int, screen_height: c_int, rec: *recorder.Recorder) Server {
        return .{
            .socket = win32.INVALID_SOCKET,
            .allocator = allocator,
            .screen = .{ .width = screen_width, .height = screen_height },
            .running = false,
            .rec = rec,
        };
    }

    /// Free resources
    pub fn deinit(self: *Server) void {
        self.stop();
    }

    /// Start the HTTP server on the given port
    pub fn start(self: *Server, port: u16) errors.ServerError!void {
        // Initialize Winsock
        var wsa_data: win32.WSAData = undefined;
        if (win32.WSAStartup(0x0202, &wsa_data) != 0) {
            return error.WSAStartupFailed;
        }

        // Create socket
        self.socket = win32.socket(win32.AF_INET, win32.SOCK_STREAM, win32.IPPROTO_TCP);
        if (self.socket == win32.INVALID_SOCKET) {
            _ = win32.WSACleanup();
            return error.SocketCreationFailed;
        }

        // Bind to port
        var addr: win32.SOCKADDR_IN = .{
            .sin_family = @intCast(win32.AF_INET),
            .sin_port = std.mem.nativeToBig(u16, port),
            .sin_addr = 0,
            .sin_zero = .{0} ** 8,
        };

        if (win32.bind(self.socket, &addr, @sizeOf(win32.SOCKADDR_IN)) != 0) {
            _ = win32.closesocket(self.socket);
            _ = win32.WSACleanup();
            return error.BindFailed;
        }

        // Listen
        if (win32.listen(self.socket, 5) != 0) {
            _ = win32.closesocket(self.socket);
            _ = win32.WSACleanup();
            return error.ListenFailed;
        }

        // Set non-blocking mode
        var mode: u32 = 1;
        _ = win32.ioctlsocket(self.socket, win32.FIONBIO, &mode);

        self.running = true;
    }

    /// Stop the HTTP server
    pub fn stop(self: *Server) void {
        self.running = false;
        if (self.socket != win32.INVALID_SOCKET) {
            _ = win32.closesocket(self.socket);
            self.socket = win32.INVALID_SOCKET;
        }
        _ = win32.WSACleanup();
    }

    /// Check if server is running
    pub fn isRunning(self: *const Server) bool {
        return self.running;
    }

    /// Process incoming connections (call periodically in main loop)
    pub fn poll(self: *Server) void {
        if (!self.running) return;

        // Accept new connection
        var client_addr: win32.SOCKADDR_IN = undefined;
        var client_addr_len: i32 = @sizeOf(win32.SOCKADDR_IN);

        const client = win32.accept(self.socket, &client_addr, &client_addr_len);
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
        self.handleRequest(client, request) catch {
            sendError(client, 500, "Internal Server Error");
        };

        _ = win32.closesocket(client);
    }

    /// HTTP request handling
    fn handleRequest(self: *Server, client: win32.SOCKET, request: []const u8) !void {
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
        self.routeRequest(client, method, path, query, body);
    }

    /// Route request to appropriate handler
    fn routeRequest(self: *Server, client: win32.SOCKET, method: []const u8, path: []const u8, query: []const u8, body: []const u8) void {
        if (std.mem.eql(u8, path, "/")) {
            sendJson(client, 200, "{\"name\":\"zmouse\",\"version\":\"1.0\"}");
        } else if (std.mem.eql(u8, path, "/api/position")) {
            self.handleGetPosition(client);
        } else if (std.mem.eql(u8, path, "/api/move")) {
            if (std.mem.eql(u8, method, "POST"))
                self.handleMove(client, body)
            else
                sendError(client, 405, "Method Not Allowed");
        } else if (std.mem.eql(u8, path, "/api/click")) {
            if (std.mem.eql(u8, method, "POST"))
                self.handleClick(client, body)
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
            self.handleScreenshot(client, query);
        } else if (std.mem.eql(u8, path, "/api/recording/status")) {
            self.handleRecordingStatus(client);
        } else if (std.mem.eql(u8, path, "/api/recording/start")) {
            if (std.mem.eql(u8, method, "POST"))
                self.handleRecordingStart(client)
            else
                sendError(client, 405, "Method Not Allowed");
        } else if (std.mem.eql(u8, path, "/api/recording/stop")) {
            if (std.mem.eql(u8, method, "POST"))
                self.handleRecordingStop(client)
            else
                sendError(client, 405, "Method Not Allowed");
        } else if (std.mem.eql(u8, path, "/api/recording/save")) {
            if (std.mem.eql(u8, method, "POST"))
                self.handleRecordingSave(client, body)
            else
                sendError(client, 405, "Method Not Allowed");
        } else if (std.mem.eql(u8, path, "/api/recording/load")) {
            if (std.mem.eql(u8, method, "POST"))
                self.handleRecordingLoad(client, body)
            else
                sendError(client, 405, "Method Not Allowed");
        } else if (std.mem.eql(u8, path, "/api/recording/play")) {
            if (std.mem.eql(u8, method, "POST"))
                self.handleRecordingPlay(client)
            else
                sendError(client, 405, "Method Not Allowed");
        } else {
            sendError(client, 404, "Not Found");
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  Route Handlers
    // ═══════════════════════════════════════════════════════════════════

    fn handleGetPosition(self: *Server, client: win32.SOCKET) void {
        _ = self;
        if (mouse.getPosition()) |pos| {
            var buf: [128]u8 = undefined;
            const json = std.fmt.bufPrint(&buf, "{{\"x\":{d},\"y\":{d}}}", .{ pos.x, pos.y }) catch return;
            sendJson(client, 200, json);
        } else {
            sendError(client, 500, "Could not get position");
        }
    }

    fn handleMove(self: *Server, client: win32.SOCKET, body: []const u8) void {
        const x = parseJsonInt(body, "x") orelse return sendError(client, 400, "Missing x");
        const y = parseJsonInt(body, "y") orelse return sendError(client, 400, "Missing y");

        mouse.moveMouse(x, y, self.screen) catch {
            sendError(client, 500, "Move failed");
            return;
        };
        sendJson(client, 200, "{\"ok\":true}");
    }

    fn handleClick(self: *Server, client: win32.SOCKET, body: []const u8) void {
        const x = parseJsonInt(body, "x") orelse return sendError(client, 400, "Missing x");
        const y = parseJsonInt(body, "y") orelse return sendError(client, 400, "Missing y");
        const button = parseJsonString(body, "button") orelse "left";

        mouse.moveMouse(x, y, self.screen) catch {
            sendError(client, 500, "Move failed");
            return;
        };

        if (std.mem.eql(u8, button, "right")) {
            mouse.rightClick();
        } else if (std.mem.eql(u8, button, "double")) {
            mouse.doubleClick();
        } else {
            mouse.leftClick();
        }

        sendJson(client, 200, "{\"ok\":true}");
    }

    fn handleScreenshot(self: *Server, client: win32.SOCKET, query: []const u8) void {
        var shot = screenshot.captureScreen(self.allocator) orelse {
            sendError(client, 500, "Could not capture screen");
            return;
        };
        defer shot.deinit();

        if (std.mem.indexOf(u8, query, "base64") != null) {
            const bmp_data = screenshot.encodeBmp(&shot, self.allocator) orelse {
                sendError(client, 500, "Could not encode BMP");
                return;
            };
            defer self.allocator.free(bmp_data);

            const b64 = screenshot.encodeBase64(bmp_data, self.allocator) catch {
                sendError(client, 500, "Could not encode base64");
                return;
            };
            defer self.allocator.free(b64);

            var buf: [1024]u8 = undefined;
            const json = std.fmt.bufPrint(&buf, "{{\"image\":\"{s}\"}}", .{b64}) catch return;
            sendJson(client, 200, json);
        } else {
            const bmp_data = screenshot.encodeBmp(&shot, self.allocator) orelse {
                sendError(client, 500, "Could not encode BMP");
                return;
            };
            defer self.allocator.free(bmp_data);

            sendBinary(client, "image/bmp", bmp_data);
        }
    }

    fn handleRecordingStatus(self: *Server, client: win32.SOCKET) void {
        var buf: [128]u8 = undefined;
        const json = std.fmt.bufPrint(&buf, "{{\"recording\":{},\"events\":{d}}}", .{
            self.rec.isRecording(),
            self.rec.getEventCount(),
        }) catch return;
        sendJson(client, 200, json);
    }

    fn handleRecordingStart(self: *Server, client: win32.SOCKET) void {
        self.rec.startRecording() catch {
            sendError(client, 500, "Could not start recording");
            return;
        };
        sendJson(client, 200, "{\"ok\":true}");
    }

    fn handleRecordingStop(self: *Server, client: win32.SOCKET) void {
        self.rec.stopRecording();
        var buf: [128]u8 = undefined;
        const json = std.fmt.bufPrint(&buf, "{{\"ok\":true,\"events\":{d}}}", .{self.rec.getEventCount()}) catch return;
        sendJson(client, 200, json);
    }

    fn handleRecordingSave(self: *Server, client: win32.SOCKET, body: []const u8) void {
        const filename = parseJsonString(body, "filename") orelse return sendError(client, 400, "Missing filename");

        const events = self.rec.getEvents();
        json_io.saveEvents(events, filename, self.allocator) catch {
            sendError(client, 500, "Could not save");
            return;
        };

        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf, "{{\"ok\":true,\"events\":{d}}}", .{events.len}) catch return;
        sendJson(client, 200, json);
    }

    fn handleRecordingLoad(self: *Server, client: win32.SOCKET, body: []const u8) void {
        const filename = parseJsonString(body, "filename") orelse return sendError(client, 400, "Missing filename");

        const events = json_io.loadEvents(filename, self.allocator) catch {
            sendError(client, 500, "Could not load");
            return;
        };
        defer self.allocator.free(events);

        self.rec.setEvents(events) catch {
            sendError(client, 500, "Could not set events");
            return;
        };

        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf, "{{\"ok\":true,\"events\":{d}}}", .{events.len}) catch return;
        sendJson(client, 200, json);
    }

    fn handleRecordingPlay(self: *Server, client: win32.SOCKET) void {
        const events = self.rec.getEvents();
        if (events.len == 0) {
            sendError(client, 400, "No events to play");
            return;
        }

        var prev_time: i64 = 0;
        for (events) |event| {
            if (event.timestamp_ms > prev_time) {
                const delay: u32 = @intCast(event.timestamp_ms - prev_time);
                win32.Sleep(delay);
            }
            prev_time = event.timestamp_ms;

            switch (event.event_type) {
                .move => mouse.moveMouse(event.x, event.y, self.screen) catch {},
                .left_down => mouse.sendMouseEvent(win32.MOUSEEVENTF_LEFTDOWN),
                .left_up => mouse.sendMouseEvent(win32.MOUSEEVENTF_LEFTUP),
                .right_down => mouse.sendMouseEvent(win32.MOUSEEVENTF_RIGHTDOWN),
                .right_up => mouse.sendMouseEvent(win32.MOUSEEVENTF_RIGHTUP),
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
};

// ═══════════════════════════════════════════════════════════════════════
//  Static Route Handlers (don't need self)
// ═══════════════════════════════════════════════════════════════════════

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
        mouse.sendKey(@intCast(key), false);
        mouse.sendKey(@intCast(key), true);
    }

    sendJson(client, 200, "{\"ok\":true}");
}

// ═══════════════════════════════════════════════════════════════════════
//  HTTP Response Helpers
// ═══════════════════════════════════════════════════════════════════════

fn sendJson(client: win32.SOCKET, status: u16, body: []const u8) void {
    var buf: [2048]u8 = undefined;
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
//  JSON Parsing Helpers
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
