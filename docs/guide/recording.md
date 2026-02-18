# Recording & Playback

ZMouse can record mouse and keyboard events and replay them later with preserved timing.

## How Recording Works

When you start recording, ZMouse installs Windows low-level hooks that capture:

- Mouse movements
- Mouse clicks (left, right, double)
- Mouse scroll events
- Keyboard key presses and releases

All events are timestamped relative to when recording started.

## Recording Commands

### Start Recording

```
> rec
  Recording started. Use 'stop' to finish.
```

While recording, ZMouse captures all system-wide mouse and keyboard input.

### Stop Recording

```
> stop
  Recording stopped. 42 events captured.
```

### View Event Count

```
> g
  Mouse position: (500, 300)

> rec
  Recording started...

> stop
  Recording stopped. 15 events captured.
```

## Saving & Loading

### Save to File

```
> save my_macro.json
  Saved 42 events to 'my_macro.json'
```

### Load from File

```
> load my_macro.json
  Loaded 42 events from 'my_macro.json'
```

## Playback

### Play Recorded Events

```
> play
  Playing 42 events...
  Playback complete.
```

During playback:
- Events are replayed in the order they were recorded
- Timing between events is preserved
- Mouse movements, clicks, and keyboard input are simulated

## JSON Format

Events are stored in JSON format:

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

### Event Types

| Type | Description |
|------|-------------|
| `move` | Mouse movement |
| `left_down` | Left mouse button pressed |
| `left_up` | Left mouse button released |
| `right_down` | Right mouse button pressed |
| `right_up` | Right mouse button released |
| `wheel` | Mouse scroll |
| `key_down` | Keyboard key pressed |
| `key_up` | Keyboard key released |

### Fields

| Field | Description |
|-------|-------------|
| `t` | Timestamp in milliseconds |
| `type` | Event type |
| `x`, `y` | Mouse coordinates (0 for keyboard) |
| `data` | Wheel delta or virtual key code |

## Use Cases

- **Automation**: Record repetitive tasks and replay them
- **Testing**: Record UI interactions for automated testing
- **Macros**: Create reusable input sequences
- **Remote control**: Record on one machine, replay via HTTP API

## Tips

- Keep recordings short for reliability
- Avoid recording sensitive keyboard input (passwords)
- Test recordings before using in production
- Use relative timing for more reliable playback
