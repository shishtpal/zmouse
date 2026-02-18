# JSON Format

ZMouse stores recorded events in JSON format for easy editing and portability.

## File Structure

```json
{
  "version": 1,
  "events": [
    {"t": 0, "type": "move", "x": 500, "y": 300},
    {"t": 150, "type": "left_down", "x": 500, "y": 300},
    {"t": 200, "type": "left_up", "x": 500, "y": 300},
    {"t": 500, "type": "key_down", "x": 0, "y": 0, "data": 65},
    {"t": 550, "type": "key_up", "x": 0, "y": 0, "data": 65}
  ]
}
```

## Fields

### Top Level

| Field | Type | Description |
|-------|------|-------------|
| `version` | number | Format version (currently 1) |
| `events` | array | Array of event objects |

### Event Object

| Field | Type | Description |
|-------|------|-------------|
| `t` | number | Timestamp in milliseconds since recording started |
| `type` | string | Event type |
| `x` | number | Mouse X coordinate (0 for keyboard events) |
| `y` | number | Mouse Y coordinate (0 for keyboard events) |
| `data` | number | (Optional) Wheel delta or virtual key code |

## Event Types

| Type | Description |
|------|-------------|
| `move` | Mouse cursor moved |
| `left_down` | Left mouse button pressed |
| `left_up` | Left mouse button released |
| `right_down` | Right mouse button pressed |
| `right_up` | Right mouse button released |
| `wheel` | Mouse scroll wheel |
| `key_down` | Keyboard key pressed |
| `key_up` | Keyboard key released |

## Data Field

The `data` field is only present for certain event types:

### Wheel Events

For `wheel` events, `data` contains the scroll delta:
- Positive values: scroll up
- Negative values: scroll down
- Units are multiples of 120 (WHEEL_DELTA)

```json
{"t": 300, "type": "wheel", "x": 500, "y": 300, "data": 120}
```

### Keyboard Events

For `key_down` and `key_up` events, `data` contains the virtual key code:

```json
{"t": 500, "type": "key_down", "x": 0, "y": 0, "data": 65}
```

Common virtual key codes:

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
| 37 | Left Arrow |
| 38 | Up Arrow |
| 39 | Right Arrow |
| 40 | Down Arrow |
| 48-57 | 0-9 |
| 65-90 | A-Z |
| 112-123 | F1-F12 |

## Example: Click Sequence

A single left-click at (500, 300):

```json
{
  "version": 1,
  "events": [
    {"t": 0, "type": "move", "x": 500, "y": 300},
    {"t": 50, "type": "left_down", "x": 500, "y": 300},
    {"t": 100, "type": "left_up", "x": 500, "y": 300}
  ]
}
```

## Example: Double-Click

A double-click at (200, 200):

```json
{
  "version": 1,
  "events": [
    {"t": 0, "type": "move", "x": 200, "y": 200},
    {"t": 50, "type": "left_down", "x": 200, "y": 200},
    {"t": 100, "type": "left_up", "x": 200, "y": 200},
    {"t": 150, "type": "left_down", "x": 200, "y": 200},
    {"t": 200, "type": "left_up", "x": 200, "y": 200}
  ]
}
```

## Library Usage

```zig
const zmouse = @import("zmouse");

// Save events
try zmouse.storage.saveEvents(events, "macro.json", allocator);

// Load events
const loaded = try zmouse.storage.loadEvents("macro.json", allocator);
defer allocator.free(loaded);
```

## Manual Editing Tips

- Keep timestamps in ascending order
- Match `_down` events with corresponding `_up` events
- Use consistent timing gaps (50-100ms typical)
- Test after editing to ensure correct playback
