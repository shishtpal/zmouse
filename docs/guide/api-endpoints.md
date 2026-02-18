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

**Button options:** `left`, `right`, `double`

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

**Direction options:** `up`, `down`

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

```json
{"error": "Missing x"}
```

HTTP status codes:
- `200` - Success
- `400` - Bad request (missing/invalid parameters)
- `404` - Not found
- `405` - Method not allowed
- `500` - Internal server error
