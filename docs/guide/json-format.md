# JSON Format

Reference for the JSON format used in recordings and API responses.

## Recording File Format

```json
{
  "version": 1,
  "events": [
    {"t": 0, "type": "move", "x": 500, "y": 300},
    {"t": 150, "type": "left_down", "x": 500, "y": 300},
    {"t": 200, "type": "left_up", "x": 500, "y": 300},
    {"t": 500, "type": "wheel", "x": 500, "y": 300, "data": 120},
    {"t": 1000, "type": "key_down", "x": 0, "y": 0, "data": 65},
    {"t": 1050, "type": "key_up", "x": 0, "y": 0, "data": 65}
  ]
}
```

## Event Types

### Mouse Events

| Type | Description | Fields |
|------|-------------|--------|
| `move` | Mouse movement | `x`, `y` |
| `left_down` | Left button pressed | `x`, `y` |
| `left_up` | Left button released | `x`, `y` |
| `right_down` | Right button pressed | `x`, `y` |
| `right_up` | Right button released | `x`, `y` |
| `wheel` | Mouse scroll | `x`, `y`, `data` |

### Keyboard Events

| Type | Description | Fields |
|------|-------------|--------|
| `key_down` | Key pressed | `data` (virtual key code) |
| `key_up` | Key released | `data` (virtual key code) |

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `t` | integer | Timestamp in milliseconds since recording started |
| `type` | string | Event type identifier |
| `x` | integer | Mouse X coordinate in pixels (0 for keyboard) |
| `y` | integer | Mouse Y coordinate in pixels (0 for keyboard) |
| `data` | integer | Additional data (wheel delta or virtual key code) |

## Virtual Key Codes

Common Windows virtual key codes:

| Code | Key |
|------|-----|
| 8 | Backspace |
| 9 | Tab |
| 13 | Enter |
| 16 | Shift |
| 17 | Ctrl |
| 18 | Alt |
| 27 | Escape |
| 32 | Space |
| 37-40 | Arrow keys |
| 48-57 | 0-9 |
| 65-90 | A-Z |
| 112-123 | F1-F12 |

Full reference: [Microsoft Docs - Virtual Key Codes](https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes)

## API Response Format

### Success

```json
{"ok": true}
```

### Success with Data

```json
{"x": 500, "y": 300}
```

```json
{"recording": false, "events": 42}
```

### Error

```json
{"error": "Missing x"}
```

## Creating Recordings Programmatically

You can create recording files manually:

```json
{
  "version": 1,
  "events": [
    {"t": 0, "type": "move", "x": 100, "y": 100},
    {"t": 100, "type": "left_down", "x": 100, "y": 100},
    {"t": 150, "type": "left_up", "x": 100, "y": 100}
  ]
}
```

Load and play via HTTP:

```bash
curl -X POST http://localhost:4000/api/recording/load -d '{"filename":"custom.json"}'
curl -X POST http://localhost:4000/api/recording/play
```
