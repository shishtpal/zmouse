# HTTP API

ZMouse includes a built-in HTTP server for remote control from web applications, browser extensions, or any HTTP client.

## Starting the HTTP Server

```bash
# Default port 4000
zig build run -- --http

# Custom port
zig build run -- --http 8080
```

The server starts and you'll see:

```
HTTP server started on port 4000
API endpoints: /api/position, /api/move, /api/click, /api/screenshot, etc.
```

The HTTP server runs in non-blocking mode, so you can still use the CLI.

## Quick Examples

```bash
# Get mouse position
curl http://localhost:4000/api/position
# {"x":500,"y":300}

# Move mouse
curl -X POST http://localhost:4000/api/move -d '{"x":800,"y":400}'
# {"ok":true}

# Click
curl -X POST http://localhost:4000/api/click -d '{"x":100,"y":100,"button":"left"}'
# {"ok":true}

# Take screenshot
curl http://localhost:4000/api/screenshot > screen.bmp
```

## CORS Support

All endpoints include `Access-Control-Allow-Origin: *` for cross-origin requests from web apps.

## Response Format

All responses are JSON:

```json
// Success
{"ok":true}

// Success with data
{"x":500,"y":300}

// Error
{"error":"Missing x"}
```

## Library Usage

```zig
const zmouse = @import("zmouse");

// Initialize
const screen = try zmouse.input.getScreenDimensions();
var recorder = zmouse.Recorder.init(allocator);
defer recorder.deinit();

// Create server
var server = zmouse.Server.init(allocator, screen.width, screen.height, &recorder);
defer server.deinit();

// Start
try server.start(4000);

// Poll in your main loop
while (running) {
    if (server.isRunning()) {
        server.poll();
    }
    // ... other work ...
}

// Stop
server.stop();
```

## Next Steps

- [API Endpoints](/guide/api-endpoints) - Full endpoint reference
- [JSON Format](/guide/json-format) - Event JSON structure
- [Screenshots](/guide/screenshots) - Screenshot API details
