//! Screenshot capture using Win32 GDI
//! Captures the screen and returns raw BGRA pixel data

const std = @import("std");
const win32 = @import("win32.zig");

/// Captured screenshot data
pub const Screenshot = struct {
    width: u32,
    height: u32,
    pixels: []u8, // BGRA format (4 bytes per pixel)
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Screenshot) void {
        self.allocator.free(self.pixels);
    }
};

/// Capture the entire screen
pub fn captureScreen(alloc: std.mem.Allocator) ?Screenshot {
    // Get screen dimensions
    const width = win32.GetSystemMetrics(win32.SM_CXSCREEN);
    const height = win32.GetSystemMetrics(win32.SM_CYSCREEN);

    if (width <= 0 or height <= 0) return null;

    return captureRect(alloc, 0, 0, @intCast(width), @intCast(height));
}

/// Capture a rectangular region of the screen
pub fn captureRect(alloc: std.mem.Allocator, x: i32, y: i32, width: u32, height: u32) ?Screenshot {
    // Get DC for the desktop
    const screen_dc = win32.GetDC(null) orelse return null;
    defer _ = win32.ReleaseDC(null, screen_dc);

    // Create compatible DC and bitmap
    const mem_dc = win32.CreateCompatibleDC(screen_dc) orelse return null;
    defer _ = win32.DeleteDC(mem_dc);

    const bitmap = win32.CreateCompatibleBitmap(screen_dc, @intCast(width), @intCast(height)) orelse return null;
    defer _ = win32.DeleteObject(@ptrCast(bitmap));

    // Select bitmap into memory DC
    _ = win32.SelectObject(mem_dc, @ptrCast(bitmap));

    // Copy screen to bitmap
    _ = win32.BitBlt(
        mem_dc,
        0,
        0,
        @intCast(width),
        @intCast(height),
        screen_dc,
        x,
        y,
        win32.SRCCOPY,
    );

    // Prepare BITMAPINFO for GetDIBits
    var bmi: win32.BITMAPINFO = .{
        .bmiHeader = .{
            .biSize = @sizeOf(win32.BITMAPINFOHEADER),
            .biWidth = @intCast(width),
            .biHeight = -@as(c_long, @intCast(height)), // Negative for top-down
            .biPlanes = 1,
            .biBitCount = 32,
            .biCompression = win32.BI_RGB,
            .biSizeImage = 0,
            .biXPelsPerMeter = 0,
            .biYPelsPerMeter = 0,
            .biClrUsed = 0,
            .biClrImportant = 0,
        },
        .bmiColors = .{0},
    };

    // Allocate pixel buffer (4 bytes per pixel: BGRA)
    const pixel_count = @as(usize, width) * @as(usize, height);
    const pixels = alloc.alloc(u8, pixel_count * 4) catch return null;

    // Get bitmap bits
    const result = win32.GetDIBits(
        mem_dc,
        bitmap,
        0,
        @intCast(height),
        pixels.ptr,
        &bmi,
        win32.DIB_RGB_COLORS,
    );

    if (result == 0) {
        alloc.free(pixels);
        return null;
    }

    return .{
        .width = width,
        .height = height,
        .pixels = pixels,
        .allocator = alloc,
    };
}

/// Encode screenshot as simple BMP (for quick implementation)
/// Returns owned slice that must be freed by caller
pub fn encodeBmp(screenshot: *const Screenshot, alloc: std.mem.Allocator) ?[]u8 {
    const width = screenshot.width;
    const height = screenshot.height;
    const row_size = width * 4;
    const pixel_size = row_size * height;

    // BMP file header (14 bytes) + DIB header (40 bytes) + pixel data
    const file_size = 14 + 40 + pixel_size;

    const bmp = alloc.alloc(u8, file_size) catch return null;
    errdefer alloc.free(bmp);

    // BMP file header
    bmp[0] = 'B';
    bmp[1] = 'M';
    // File size
    std.mem.writeInt(u32, bmp[2..6], @intCast(file_size), .little);
    // Reserved
    std.mem.writeInt(u32, bmp[6..10], 0, .little);
    // Pixel data offset
    std.mem.writeInt(u32, bmp[10..14], 54, .little);

    // DIB header (BITMAPINFOHEADER)
    std.mem.writeInt(u32, bmp[14..18], 40, .little); // Header size
    std.mem.writeInt(i32, bmp[18..22], @intCast(width), .little); // Width
    std.mem.writeInt(i32, bmp[22..26], @intCast(height), .little); // Height
    std.mem.writeInt(u16, bmp[26..28], 1, .little); // Planes
    std.mem.writeInt(u16, bmp[28..30], 32, .little); // Bits per pixel
    std.mem.writeInt(u32, bmp[30..34], 0, .little); // Compression (BI_RGB)
    std.mem.writeInt(u32, bmp[34..38], @intCast(pixel_size), .little); // Image size
    std.mem.writeInt(i32, bmp[38..42], 2835, .little); // X pixels per meter
    std.mem.writeInt(i32, bmp[42..46], 2835, .little); // Y pixels per meter
    std.mem.writeInt(u32, bmp[46..50], 0, .little); // Colors used
    std.mem.writeInt(u32, bmp[50..54], 0, .little); // Important colors

    // Pixel data (already in BGRA format from GetDIBits)
    @memcpy(bmp[54..], screenshot.pixels);

    return bmp;
}

// ═══════════════════════════════════════════════════════════════════════
//  JPEG Encoding via GDI+
// ═══════════════════════════════════════════════════════════════════════

var gdiplus_token: usize = 0;
var gdiplus_initialized: bool = false;

/// Initialize GDI+ (call once at startup)
pub fn initGdiPlus() bool {
    if (gdiplus_initialized) return true;

    var input = win32.GdiplusStartupInput{};
    const status = win32.GdiplusStartup(&gdiplus_token, &input, null);
    if (status == .Ok) {
        gdiplus_initialized = true;
        return true;
    }
    return false;
}

/// Shutdown GDI+ (call at cleanup)
pub fn shutdownGdiPlus() void {
    if (gdiplus_initialized) {
        win32.GdiplusShutdown(gdiplus_token);
        gdiplus_initialized = false;
    }
}

/// Encode screenshot as JPEG using GDI+
/// quality: 0-100 (default 85)
/// Returns owned slice that must be freed by caller
pub fn encodeJpeg(screenshot: *const Screenshot, alloc: std.mem.Allocator, quality: u32) ?[]u8 {
    if (!initGdiPlus()) return null;

    const width = screenshot.width;
    const height = screenshot.height;

    // Get screen DC for creating compatible bitmap
    const screen_dc = win32.GetDC(null) orelse return null;
    defer _ = win32.ReleaseDC(null, screen_dc);

    // Create memory DC
    const mem_dc = win32.CreateCompatibleDC(screen_dc) orelse return null;
    defer _ = win32.DeleteDC(mem_dc);

    // Create DIB section with our pixel data
    var bmi: win32.BITMAPINFO = .{
        .bmiHeader = .{
            .biSize = @sizeOf(win32.BITMAPINFOHEADER),
            .biWidth = @intCast(width),
            .biHeight = -@as(c_long, @intCast(height)), // Top-down
            .biPlanes = 1,
            .biBitCount = 32,
            .biCompression = win32.BI_RGB,
            .biSizeImage = 0,
            .biXPelsPerMeter = 0,
            .biYPelsPerMeter = 0,
            .biClrUsed = 0,
            .biClrImportant = 0,
        },
        .bmiColors = .{0},
    };

    var bits_ptr: ?*anyopaque = null;
    const dib = win32.CreateDIBSection(screen_dc, &bmi, win32.DIB_RGB_COLORS, &bits_ptr, null, 0) orelse return null;
    defer _ = win32.DeleteObject(@ptrCast(dib));

    // Copy our pixels to the DIB
    if (bits_ptr) |ptr| {
        const dest: [*]u8 = @ptrCast(ptr);
        @memcpy(dest[0..screenshot.pixels.len], screenshot.pixels);
    } else {
        return null;
    }

    // Create GDI+ bitmap from HBITMAP
    var gp_bitmap: *win32.GpBitmap = undefined;
    if (win32.GdipCreateBitmapFromHBITMAP(dib, null, &gp_bitmap) != .Ok) {
        return null;
    }
    defer _ = win32.GdipDisposeImage(@ptrCast(gp_bitmap));

    // Create IStream for output
    var stream: *win32.IStream = undefined;
    if (win32.CreateStreamOnHGlobal(null, 1, &stream) != 0) {
        return null;
    }
    defer {
        // Get vtable and call Release
        const vtbl_ptr: *const *const win32.IStreamVtbl = @ptrCast(@alignCast(stream));
        _ = vtbl_ptr.*.Release(stream);
    }

    // Set up encoder parameters for quality
    var quality_value: u32 = if (quality > 100) 100 else quality;
    var encoder_params = win32.EncoderParameters{
        .Count = 1,
        .Parameter = .{.{
            .Guid = win32.EncoderQuality,
            .NumberOfValues = 1,
            .Type = win32.EncoderParameterValueTypeLong,
            .Value = @ptrCast(&quality_value),
        }},
    };

    // Save to stream as JPEG
    if (win32.GdipSaveImageToStream(@ptrCast(gp_bitmap), stream, &win32.CLSID_JpegEncoder, &encoder_params) != .Ok) {
        return null;
    }

    // Get the data from stream
    var hglobal: win32.HGLOBAL = undefined;
    if (win32.GetHGlobalFromStream(stream, &hglobal) != 0) {
        return null;
    }

    const size = win32.GlobalSize(hglobal);
    if (size == 0) return null;

    const locked = win32.GlobalLock(hglobal) orelse return null;
    defer _ = win32.GlobalUnlock(hglobal);

    // Copy to our allocator
    const result = alloc.alloc(u8, size) catch return null;
    const src: [*]const u8 = @ptrCast(locked);
    @memcpy(result, src[0..size]);

    return result;
}

/// Base64 encoding table
const BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

/// Encode data as base64
pub fn encodeBase64(data: []const u8, alloc: std.mem.Allocator) ![]u8 {
    const out_len = ((data.len + 2) / 3) * 4;
    const result = try alloc.alloc(u8, out_len);

    var i: usize = 0;
    var j: usize = 0;

    while (i < data.len) {
        const a: u8 = if (i < data.len) data[i] else 0;
        const b: u8 = if (i + 1 < data.len) data[i + 1] else 0;
        const c: u8 = if (i + 2 < data.len) data[i + 2] else 0;

        result[j] = BASE64_CHARS[(a >> 2) & 0x3F];
        result[j + 1] = BASE64_CHARS[((a << 4) | (b >> 4)) & 0x3F];
        result[j + 2] = if (i + 1 < data.len) BASE64_CHARS[((b << 2) | (c >> 6)) & 0x3F] else '=';
        result[j + 3] = if (i + 2 < data.len) BASE64_CHARS[c & 0x3F] else '=';

        i += 3;
        j += 4;
    }

    return result;
}
