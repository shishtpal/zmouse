# Recording & Playback

ZMouse can record mouse and keyboard events and replay them later with preserved timing.

## How Recording Works

When you start recording, ZMouse installs Windows low-level hooks that capture:

- Mouse movements
- Mouse clicks (left, right, double)
- Mouse scroll events
- Keyboard key presses and releases

All events are timestamped relative to when recording started.

## CLI Recording

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

### Playback

```
> play
  Playing 42 events...
  Playback complete.
```

## HTTP API Recording

### Check Status

```bash
curl http://localhost:4000/api/recording/status
# {"recording":false,"events":0}
```

### Start Recording

```bash
curl -X POST http://localhost:4000/api/recording/start
# {"ok":true}
```

### Stop Recording

```bash
curl -X POST http://localhost:4000/api/recording/stop
# {"ok":true,"events":42}
```

### Save Events

```bash
curl -X POST http://localhost:4000/api/recording/save \
  -d '{"filename":"macro.json"}'
# {"ok":true,"events":42}
```

### Load Events

```bash
curl -X POST http://localhost:4000/api/recording/load \
  -d '{"filename":"macro.json"}'
# {"ok":true,"events":42}
```

### Playback

```bash
curl -X POST http://localhost:4000/api/recording/play
# {"ok":true}
```

## Library API

```zig
const zmouse = @import("zmouse");

// Initialize recorder
var recorder = zmouse.Recorder.init(allocator);
defer recorder.deinit();

// Start recording
try recorder.startRecording();

// ... user performs actions ...

// Stop recording
recorder.stopRecording();

// Get event count
const count = recorder.getEventCount();

// Get events
const events = recorder.getEvents();

// Save to file
try zmouse.storage.saveEvents(events, "macro.json", allocator);

// Load from file
const loaded = try zmouse.storage.loadEvents("macro.json", allocator);
defer allocator.free(loaded);

// Set events from loaded data
try recorder.setEvents(loaded);

// Clear events
recorder.clearEvents();
```

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

## Architecture

```
┌─────────────────┐
│   Main Thread   │
│   (REPL/HTTP)   │
└────────┬────────┘
         │ startRecording()
         ▼
┌─────────────────┐
│  Hook Thread    │
│  (message pump) │
│                 │
│ WH_MOUSE_LL     │◄── System mouse events
│ WH_KEYBOARD_LL  │◄── System keyboard events
└────────┬────────┘
         │ appendEvent()
         ▼
┌─────────────────┐
│ Recorder.events │
│ (ArrayListUnmanaged)
└─────────────────┘
```

The hook thread runs a Windows message pump to receive low-level input events. Events are stored with timestamps for accurate playback.

## Use Cases

- **Automation**: Record repetitive tasks and replay them
- **Testing**: Record UI interactions for automated testing
- **Macros**: Create reusable input sequences
- **Remote control**: Record on one machine, replay via HTTP API

## Tips

- Keep recordings short for reliability
- Avoid recording sensitive keyboard input (passwords)
- Test recordings before using in production
- Playback timing is preserved from the original recording
