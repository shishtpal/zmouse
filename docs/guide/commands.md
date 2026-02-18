# Commands Reference

## Mouse Commands

| Command | Description | Example |
|---------|-------------|---------|
| `m<X>-<Y>` | Move mouse to coordinates | `m500-300` |
| `c<X>-<Y>` | Move and left-click | `c100-100` |
| `r<X>-<Y>` | Move and right-click | `r200-200` |
| `d<X>-<Y>` | Move and double-click | `d300-300` |
| `sc<N>` | Scroll up by N units | `sc5` |
| `sd<N>` | Scroll down by N units | `sd10` |
| `g` | Get current mouse position | `g` |

## Recording Commands

| Command | Description | Example |
|---------|-------------|---------|
| `rec` | Start recording events | `rec` |
| `stop` | Stop recording | `stop` |
| `save <file>` | Save events to JSON | `save macro.json` |
| `load <file>` | Load events from JSON | `load macro.json` |
| `play` | Replay recorded events | `play` |

## System Commands

| Command | Description |
|---------|-------------|
| `q` | Quit the program |

## Coordinate System

- Origin (0, 0) is at the top-left of the primary monitor
- X increases to the right
- Y increases downward
- Coordinates are in pixels

## Scroll Units

- Scroll values are in "wheel delta" units
- Standard WHEEL_DELTA = 120
- `sc1` scrolls up by 1/120 of a wheel notch
- `sc120` scrolls up by one full wheel notch
- Negative values scroll down

## Examples

### Click a button at specific coordinates
```
> c500-300
```

### Scroll down a page
```
> sd120
```

### Move mouse to center of 1920x1080 screen
```
> m960-540
```

### Record a sequence
```
> rec
> m100-100
> c100-100
> m200-200
> c200-200
> stop
> save sequence.json
```
