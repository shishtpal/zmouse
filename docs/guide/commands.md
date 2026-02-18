# Commands

Complete reference for all CLI commands.

## Mouse Commands

### Move Mouse

Move the mouse cursor to absolute pixel coordinates.

```
m<X>-<Y>
```

**Example:**
```
> m500-300
  Mouse moved to (500, 300)
```

### Left Click

Move and left-click at coordinates.

```
c<X>-<Y>
```

**Example:**
```
> c100-100
  Mouse moved to (100, 100) and clicked
```

### Right Click

Move and right-click at coordinates.

```
r<X>-<Y>
```

**Example:**
```
> r200-200
  Mouse moved to (200, 200) and right-clicked
```

### Double Click

Move and double-click at coordinates.

```
d<X>-<Y>
```

**Example:**
```
> d300-300
  Mouse moved to (300, 300) and double-clicked
```

### Scroll Up

Scroll the mouse wheel up.

```
sc<N>
```

**Example:**
```
> sc5
  Scrolled up by 5
```

### Scroll Down

Scroll the mouse wheel down.

```
sd<N>
```

**Example:**
```
> sd10
  Scrolled down by 10
```

### Get Position

Get the current mouse cursor position.

```
g
```

**Example:**
```
> g
  Mouse position: (1234, 567)
```

## Recording Commands

### Start Recording

Start capturing mouse and keyboard events.

```
rec
```

**Example:**
```
> rec
  Recording started. Use 'stop' to finish.
```

### Stop Recording

Stop recording and show event count.

```
stop
```

**Example:**
```
> stop
  Recording stopped. 42 events captured.
```

### Save Events

Save recorded events to a JSON file.

```
save <filename>
```

**Example:**
```
> save macro.json
  Saved 42 events to 'macro.json'
```

### Load Events

Load events from a JSON file.

```
load <filename>
```

**Example:**
```
> load macro.json
  Loaded 42 events from 'macro.json'
```

### Playback

Replay recorded/loaded events with original timing.

```
play
```

**Example:**
```
> play
  Playing 42 events...
  Playback complete.
```

## Other Commands

### Quit

Exit the program.

```
q
```

## Command Summary

| Command | Description |
|---------|-------------|
| `m<X>-<Y>` | Move mouse to (X, Y) |
| `c<X>-<Y>` | Move and left-click |
| `r<X>-<Y>` | Move and right-click |
| `d<X>-<Y>` | Move and double-click |
| `sc<N>` | Scroll up by N units |
| `sd<N>` | Scroll down by N units |
| `g` | Get mouse position |
| `rec` | Start recording |
| `stop` | Stop recording |
| `save <file>` | Save events to JSON file |
| `load <file>` | Load events from JSON file |
| `play` | Replay events |
| `q` | Quit |

## Notes

- Coordinates are in pixels, with (0,0) at top-left of the screen
- Scroll units are multiples of 120 (Windows WHEEL_DELTA)
- Recording captures both mouse and keyboard events system-wide
- Playback preserves the original timing between events
- Commands are case-sensitive
