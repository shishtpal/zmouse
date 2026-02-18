//! JSON serialization for mouse events
//! Handles saving and loading recorded events to/from JSON files

const std = @import("std");
const recorder = @import("recorder.zig");
const win32 = @import("win32.zig");

const JSON_VERSION: u32 = 1;

// Win32 file operations for simple file I/O
const GENERIC_READ: u32 = 0x80000000;
const GENERIC_WRITE: u32 = 0x40000000;
const CREATE_ALWAYS: u32 = 2;
const OPEN_EXISTING: u32 = 3;
const FILE_ATTRIBUTE_NORMAL: u32 = 0x80;
const INVALID_HANDLE_VALUE: usize = @bitCast(@as(isize, -1));

const HANDLE = *opaque {};

extern "kernel32" fn CreateFileA(
    lpFileName: [*:0]const u8,
    dwDesiredAccess: u32,
    dwShareMode: u32,
    lpSecurityAttributes: ?*anyopaque,
    dwCreationDisposition: u32,
    dwFlagsAndAttributes: u32,
    hTemplateFile: ?HANDLE,
) callconv(.winapi) HANDLE;

extern "kernel32" fn WriteFile(
    hFile: HANDLE,
    lpBuffer: [*]const u8,
    nNumberOfBytesToWrite: u32,
    lpNumberOfBytesWritten: ?*u32,
    lpOverlapped: ?*anyopaque,
) callconv(.winapi) c_int;

extern "kernel32" fn ReadFile(
    hFile: HANDLE,
    lpBuffer: [*]u8,
    nNumberOfBytesToRead: u32,
    lpNumberOfBytesRead: ?*u32,
    lpOverlapped: ?*anyopaque,
) callconv(.winapi) c_int;

extern "kernel32" fn CloseHandle(hObject: HANDLE) callconv(.winapi) c_int;

extern "kernel32" fn GetFileSize(hFile: HANDLE, lpFileSizeHigh: ?*u32) callconv(.winapi) u32;

/// Save events to a JSON file
pub fn saveEvents(events: []const recorder.MouseEvent, filepath: []const u8, alloc: std.mem.Allocator) !void {
    var json_buf = std.ArrayListUnmanaged(u8).empty;
    defer json_buf.deinit(alloc);

    // Write JSON manually (simple format)
    try json_buf.appendSlice(alloc, "{\n  \"version\": ");
    try appendInt(&json_buf, alloc, JSON_VERSION);
    try json_buf.appendSlice(alloc, ",\n  \"events\": [\n");

    for (events, 0..) |event, i| {
        try json_buf.appendSlice(alloc, "    {\"t\": ");
        try appendInt(&json_buf, alloc, @intCast(event.timestamp_ms));
        try json_buf.appendSlice(alloc, ", \"type\": \"");
        try json_buf.appendSlice(alloc, event.event_type.toString());
        try json_buf.appendSlice(alloc, "\", \"x\": ");
        try appendInt(&json_buf, alloc, event.x);
        try json_buf.appendSlice(alloc, ", \"y\": ");
        try appendInt(&json_buf, alloc, event.y);
        // Include data field for wheel and keyboard events
        if (event.event_type == .wheel or event.event_type == .key_down or event.event_type == .key_up) {
            try json_buf.appendSlice(alloc, ", \"data\": ");
            try appendInt(&json_buf, alloc, event.data);
        }
        try json_buf.appendSlice(alloc, "}");
        if (i < events.len - 1) {
            try json_buf.appendSlice(alloc, ",");
        }
        try json_buf.appendSlice(alloc, "\n");
    }

    try json_buf.appendSlice(alloc, "  ]\n}\n");

    // Create null-terminated filepath
    var path_buf: [260]u8 = undefined;
    if (filepath.len >= path_buf.len) return error.PathTooLong;
    @memcpy(path_buf[0..filepath.len], filepath);
    path_buf[filepath.len] = 0;

    // Write to file using Win32
    const handle = CreateFileA(
        @ptrCast(&path_buf),
        GENERIC_WRITE,
        0,
        null,
        CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL,
        null,
    );
    if (@intFromPtr(handle) == INVALID_HANDLE_VALUE) return error.CannotOpenFile;
    defer _ = CloseHandle(handle);

    var bytes_written: u32 = 0;
    if (WriteFile(handle, json_buf.items.ptr, @intCast(json_buf.items.len), &bytes_written, null) == 0) {
        return error.WriteError;
    }
}

fn appendInt(buf: *std.ArrayListUnmanaged(u8), alloc: std.mem.Allocator, val: i64) !void {
    var num_buf: [32]u8 = undefined;
    const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{val}) catch return error.FormatError;
    try buf.appendSlice(alloc, num_str);
}

/// Load events from a JSON file
pub fn loadEvents(filepath: []const u8, alloc: std.mem.Allocator) ![]recorder.MouseEvent {
    // Create null-terminated filepath
    var path_buf: [260]u8 = undefined;
    if (filepath.len >= path_buf.len) return error.PathTooLong;
    @memcpy(path_buf[0..filepath.len], filepath);
    path_buf[filepath.len] = 0;

    // Open file using Win32
    const handle = CreateFileA(
        @ptrCast(&path_buf),
        GENERIC_READ,
        0,
        null,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        null,
    );
    if (@intFromPtr(handle) == INVALID_HANDLE_VALUE) return error.CannotOpenFile;
    defer _ = CloseHandle(handle);

    // Get file size
    const file_size = GetFileSize(handle, null);
    if (file_size == 0xFFFFFFFF or file_size > 1024 * 1024) return error.InvalidFileSize;

    // Read file contents
    const content = try alloc.alloc(u8, file_size);
    defer alloc.free(content);

    var bytes_read: u32 = 0;
    if (ReadFile(handle, content.ptr, file_size, &bytes_read, null) == 0) {
        return error.ReadError;
    }

    return parseJson(content[0..bytes_read], alloc);
}

/// Parse JSON content into events
fn parseJson(content: []const u8, alloc: std.mem.Allocator) ![]recorder.MouseEvent {
    var events = std.ArrayListUnmanaged(recorder.MouseEvent).empty;
    errdefer events.deinit(alloc);

    // Find "events": [ and parse each object
    const events_start = std.mem.indexOf(u8, content, "\"events\":") orelse
        return error.InvalidJson;

    const array_start = std.mem.indexOfPos(u8, content, events_start, "[") orelse
        return error.InvalidJson;

    const array_end = std.mem.lastIndexOf(u8, content, "]") orelse
        return error.InvalidJson;

    const array_content = content[array_start + 1 .. array_end];

    // Parse each event object
    var pos: usize = 0;
    while (pos < array_content.len) {
        // Find next object
        const obj_start = std.mem.indexOfPos(u8, array_content, pos, "{") orelse break;
        const obj_end = std.mem.indexOfPos(u8, array_content, obj_start, "}") orelse break;

        const obj = array_content[obj_start .. obj_end + 1];

        // Parse fields
        const event = try parseEventObject(obj);
        try events.append(alloc, event);

        pos = obj_end + 1;
    }

    return try events.toOwnedSlice(alloc);
}

/// Parse a single event object
fn parseEventObject(obj: []const u8) !recorder.MouseEvent {
    var event: recorder.MouseEvent = .{
        .timestamp_ms = 0,
        .event_type = .move,
        .x = 0,
        .y = 0,
        .data = 0,
    };

    // Parse "t": <number>
    if (findNumberValue(obj, "\"t\":")) |t| {
        event.timestamp_ms = t;
    }

    // Parse "type": "<string>"
    if (findStringValue(obj, "\"type\":")) |type_str| {
        event.event_type = recorder.EventType.fromString(type_str) orelse .move;
    }

    // Parse "x": <number>
    if (findNumberValue(obj, "\"x\":")) |x| {
        event.x = @intCast(x);
    }

    // Parse "y": <number>
    if (findNumberValue(obj, "\"y\":")) |y| {
        event.y = @intCast(y);
    }

    // Parse "data": <number> (optional)
    if (findNumberValue(obj, "\"data\":")) |data| {
        event.data = @intCast(data);
    }

    return event;
}

/// Find a number value after a key
fn findNumberValue(obj: []const u8, key: []const u8) ?i64 {
    const key_pos = std.mem.indexOf(u8, obj, key) orelse return null;
    const value_start = key_pos + key.len;

    // Skip whitespace
    var start = value_start;
    while (start < obj.len and (obj[start] == ' ' or obj[start] == '\t')) {
        start += 1;
    }

    // Find end of number
    var end = start;
    if (end < obj.len and obj[end] == '-') {
        end += 1;
    }
    while (end < obj.len and obj[end] >= '0' and obj[end] <= '9') {
        end += 1;
    }

    if (start == end) return null;
    return std.fmt.parseInt(i64, obj[start..end], 10) catch null;
}

/// Find a string value after a key
fn findStringValue(obj: []const u8, key: []const u8) ?[]const u8 {
    const key_pos = std.mem.indexOf(u8, obj, key) orelse return null;
    const after_key = key_pos + key.len;

    // Find opening quote
    const quote_start = std.mem.indexOfPos(u8, obj, after_key, "\"") orelse return null;
    const str_start = quote_start + 1;

    // Find closing quote
    const quote_end = std.mem.indexOfPos(u8, obj, str_start, "\"") orelse return null;

    return obj[str_start..quote_end];
}

pub const JsonError = error{
    InvalidJson,
    OutOfMemory,
    CannotOpenFile,
    WriteError,
    ReadError,
    PathTooLong,
    InvalidFileSize,
    FormatError,
};
