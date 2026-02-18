# API Endpoints

Complete reference for all HTTP API endpoints.

## Mouse Control

### GET /api/position

Get current mouse position.

**Response:**
```json
{"x": 500, "y": 300}
```

### POST /api/move

Move mouse to coordinates.

**Request:**
```json
{"x": 800, "y": 400}
```

**Response:**
```json
{"ok": true}
```

### POST /api/click

Move and click at coordinates.

**Request:**
```json
{
  "x": 100,
  "y": 100,
  "button": "left"
}
```

**Button options:** `left` (default), `right`, `double`

**Response:**
```json
{"ok": true}
```

### POST /api/scroll

Scroll the mouse wheel.

**Request:**
```json
{
  "amount": 5,
  "direction": "up"
}
```

**Direction options:** `up` (default), `down`

**Response:**
```json
{"ok": true}
```

### POST /api/keyboard

Send keyboard input.

**Request:**
```json
{
  "key": 65,
  "action": "press"
}
```

**Action options:**
- `press` - Press and release (default)
- `down` - Key down only
- `up` - Key up only

**Key:** Virtual key code (e.g., 65 = 'A', 13 = Enter, 32 = Space)

**Response:**
```json
{"ok": true}
```

## Screenshot

### GET /api/screenshot

Capture screenshot.

**Query parameters:**
- `base64` - Return as base64 JSON instead of binary

**Response (binary):**
- Content-Type: `image/bmp`
- Body: BMP image data

**Response (base64):**
```json
{"image": "Qk1WQAAAAAAAD..."}
```

## Recording

### GET /api/recording/status

Get recording status.

**Response:**
```json
{
  "recording": false,
  "events": 42
}
```

### POST /api/recording/start

Start recording.

**Response:**
```json
{"ok": true}
```

**Error (already recording):**
```json
{"error": "Could not start recording"}
```

### POST /api/recording/stop

Stop recording.

**Response:**
```json
{
  "ok": true,
  "events": 42
}
```

### POST /api/recording/save

Save recorded events to file.

**Request:**
```json
{"filename": "macro.json"}
```

**Response:**
```json
{
  "ok": true,
  "events": 42
}
```

### POST /api/recording/load

Load events from file.

**Request:**
```json
{"filename": "macro.json"}
```

**Response:**
```json
{
  "ok": true,
  "events": 42
}
```

### POST /api/recording/play

Replay recorded events.

**Response:**
```json
{"ok": true}
```

**Error (no events):**
```json
{"error": "No events to play"}
```

Note: Playback is blocking - the request won't return until playback is complete.

## System

### GET /

API information.

**Response:**
```json
{
  "name": "zmouse",
  "version": "1.0"
}
```

## Error Responses

All errors return JSON with an `error` field:

```json
{"error": "Missing x"}
```

HTTP status codes:
- `200` - Success
- `400` - Bad request (missing/invalid parameters)
- `404` - Not found (unknown endpoint)
- `405` - Method not allowed (wrong HTTP method)
- `500` - Internal server error

## Usage Examples

### JavaScript (fetch)

```javascript
// Get position
const pos = await fetch('http://localhost:4000/api/position')
  .then(r => r.json());
console.log(`Mouse at (${pos.x}, ${pos.y})`);

// Move and click
await fetch('http://localhost:4000/api/click', {
  method: 'POST',
  body: JSON.stringify({ x: 100, y: 100, button: 'left' })
});

// Get screenshot as blob
const screenshot = await fetch('http://localhost:4000/api/screenshot')
  .then(r => r.blob());
```

### Python (requests)

```python
import requests

# Get position
pos = requests.get('http://localhost:4000/api/position').json()
print(f"Mouse at ({pos['x']}, {pos['y']})")

# Move mouse
requests.post('http://localhost:4000/api/move', json={'x': 500, 'y': 300})

# Save screenshot
response = requests.get('http://localhost:4000/api/screenshot')
with open('screenshot.bmp', 'wb') as f:
    f.write(response.content)
```

### cURL

```bash
# Get position
curl http://localhost:4000/api/position

# Move mouse
curl -X POST http://localhost:4000/api/move -d '{"x":500,"y":300}'

# Click with right button
curl -X POST http://localhost:4000/api/click -d '{"x":100,"y":100,"button":"right"}'

# Record, save, and replay
curl -X POST http://localhost:4000/api/recording/start
# ... perform actions ...
curl -X POST http://localhost:4000/api/recording/stop
curl -X POST http://localhost:4000/api/recording/save -d '{"filename":"macro.json"}'
curl -X POST http://localhost:4000/api/recording/play
```
