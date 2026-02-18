# Basic Usage

## Interactive CLI

Start the interactive CLI:

```bash
zig build run
```

You'll see a prompt where you can type commands:

```
  Mouse Controller  (screen 1920 x 1080)
  ─────────────────────────────────────
  m<X>-<Y>   move            c<X>-<Y>   move + left-click
  r<X>-<Y>   move + right    d<X>-<Y>   move + double-click
  sc<N>      scroll up       sd<N>      scroll down
  g          get position    q          quit

  Recording:
  rec           start recording mouse events
  stop          stop recording
  save <file>   save events to JSON file
  load <file>   load events from JSON file
  play          replay events

>
```

## Mouse Commands

### Move Mouse

```
> m500-300
  Mouse moved to (500, 300)
```

### Click

```
> c100-100              # Left click at (100, 100)
  Mouse moved to (100, 100) and clicked

> r200-200              # Right click
  Mouse moved to (200, 200) and right-clicked

> d300-300              # Double click
  Mouse moved to (300, 300) and double-clicked
```

### Scroll

```
> sc5                   # Scroll up 5 units
  Scrolled up by 5

> sd10                  # Scroll down 10 units
  Scrolled down by 10
```

### Get Position

```
> g
  Mouse position: (1234, 567)
```

## Recording Commands

### Record Events

```
> rec
  Recording started. Use 'stop' to finish.

(move mouse, click, type...)

> stop
  Recording stopped. 42 events captured.
```

### Save & Load

```
> save macro.json
  Saved 42 events to 'macro.json'

> load macro.json
  Loaded 42 events from 'macro.json'
```

### Playback

```
> play
  Playing 42 events...
  Playback complete.
```

## Exit

```
> q
  Exiting...
```

## Tips

- Coordinates are in pixels, with (0,0) at top-left
- Scroll units are multiples of 120 (WHEEL_DELTA)
- Recording captures both mouse and keyboard events
- Playback preserves original timing between events
