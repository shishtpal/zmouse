# Screenshots

ZMouse can capture screenshots via HTTP API.

## HTTP Endpoint

### GET /api/screenshot

Capture the entire screen.

**Binary response (default):**
```bash
curl http://localhost:4000/api/screenshot > screenshot.bmp
```

Response:
- Content-Type: `image/bmp`
- Body: BMP image data

**Base64 response:**
```bash
curl "http://localhost:4000/api/screenshot?base64"
```

Response:
```json
{"image": "Qk1WQAAAAAAAD..."}
```

## Usage Examples

### Download Screenshot (cURL)

```bash
# Save as BMP
curl http://localhost:4000/api/screenshot > screenshot.bmp

# Get as base64 JSON
curl "http://localhost:4000/api/screenshot?base64"
```

### JavaScript

```javascript
// Download as blob
const response = await fetch('http://localhost:4000/api/screenshot');
const blob = await response.blob();
const url = URL.createObjectURL(blob);

// Display in img element
const img = document.getElementById('screenshot');
img.src = url;

// Or download
const a = document.createElement('a');
a.href = url;
a.download = 'screenshot.bmp';
a.click();
```

### Python

```python
import requests

# Download binary
response = requests.get('http://localhost:4000/api/screenshot')
with open('screenshot.bmp', 'wb') as f:
    f.write(response.content)

# Get as base64
response = requests.get('http://localhost:4000/api/screenshot?base64')
base64_data = response.json()['image']
```

## Library API

```zig
const zmouse = @import("zmouse");

// Capture entire screen
var shot = zmouse.screenshot.captureScreen(allocator) orelse {
    // Handle error
    return;
};
defer shot.deinit();

// Access pixel data
const width = shot.width;
const height = shot.height;
const pixels = shot.pixels;  // BGRA format

// Encode as BMP
const bmp_data = zmouse.screenshot.encodeBmp(&shot, allocator) orelse {
    return;
};
defer allocator.free(bmp_data);

// Write to file
// (use std.fs or write manually)

// Encode as base64
const b64 = try zmouse.screenshot.encodeBase64(bmp_data, allocator);
defer allocator.free(b64);
```

### Screenshot Struct

```zig
pub const Screenshot = struct {
    width: u32,
    height: u32,
    pixels: []u8,  // BGRA format, 4 bytes per pixel
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *Screenshot) void;
};
```

### Functions

```zig
/// Capture entire screen
pub fn captureScreen(allocator: Allocator) ?Screenshot

/// Capture rectangular region
pub fn captureRect(
    allocator: Allocator,
    x: i32,
    y: i32,
    width: u32,
    height: u32
) ?Screenshot

/// Encode screenshot as BMP (caller must free)
pub fn encodeBmp(
    screenshot: *const Screenshot,
    allocator: Allocator
) ?[]u8

/// Encode bytes as base64 (caller must free)
pub fn encodeBase64(
    data: []const u8,
    allocator: Allocator
) ![]u8
```

## Technical Details

### Capture Method

Screenshots use Windows GDI:
1. `GetDC(NULL)` to get screen device context
2. `CreateCompatibleDC` and `CreateCompatibleBitmap`
3. `BitBlt` to copy screen pixels
4. `GetDIBits` to retrieve pixel data

### Pixel Format

- Format: BGRA (Blue, Green, Red, Alpha)
- 4 bytes per pixel
- Origin: Top-left corner
- Scanlines: Top to bottom

### BMP Encoding

Output is Windows BMP format:
- 24-bit color (RGB, no alpha)
- Uncompressed
- Compatible with all image viewers

## Error Handling

The screenshot API returns `null` on failure:

```zig
const shot = zmouse.screenshot.captureScreen(allocator) orelse {
    std.debug.print("Screenshot capture failed\n", .{});
    return;
};
```

Common failure reasons:
- Insufficient memory
- Display context unavailable
- Bitmap creation failed

## Performance

- Capture is synchronous (blocks until complete)
- Large screens (4K+) may take 50-100ms
- Memory usage: ~4 bytes per pixel + BMP header
- Example: 1920x1080 = ~8MB uncompressed
