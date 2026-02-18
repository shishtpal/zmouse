---
layout: home

hero:
  name: "ZMouse"
  text: "Windows Input Controller"
  tagline: Control mouse & keyboard via CLI, HTTP API, or as a Zig library
  image:
    src: /logo.svg
    alt: ZMouse
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: Library Guide
      link: /guide/library
    - theme: alt
      text: HTTP API
      link: /guide/api

features:
  - icon: 🖱️
    title: Mouse Control
    details: Move, click, scroll with precise pixel coordinates via CLI or HTTP API
  - icon: ⌨️
    title: Keyboard Control
    details: Simulate keyboard input with support for all virtual key codes
  - icon: 🔴
    title: Recording & Playback
    details: Record mouse and keyboard events, save to JSON, replay with timing
  - icon: 📡
    title: HTTP API
    details: RESTful API for remote control from any web app or browser
  - icon: 📸
    title: Screenshots
    details: Capture screen via HTTP endpoint with base64 or binary output
  - icon: 📦
    title: Library Support
    details: Import as a Zig module with full type safety and error handling
---

## Quick Start

```bash
# Build the project
zig build

# Run interactive CLI
zig build run

# Start with HTTP API on port 4000
zig build run -- --http

# Run tests
zig build test
```

## CLI Usage

```
> m500-300          # Move mouse to (500, 300)
> c100-100          # Click at (100, 100)
> sc5               # Scroll up 5 units
> g                 # Get mouse position
> rec               # Start recording
> stop              # Stop recording
> save macro.json   # Save to file
> play              # Replay events
```

## HTTP API

```bash
# Get mouse position
curl http://localhost:4000/api/position

# Move mouse
curl -X POST http://localhost:4000/api/move -d '{"x":800,"y":400}'

# Take screenshot
curl http://localhost:4000/api/screenshot > screen.bmp
```

## Library Usage

```zig
const zmouse = @import("zmouse");

// Get screen dimensions
const screen = try zmouse.input.getScreenDimensions();

// Move and click
try zmouse.input.moveMouse(500, 300, screen);
zmouse.input.leftClick();

// Recording
var recorder = zmouse.Recorder.init(allocator);
defer recorder.deinit();

try recorder.startRecording();
// ... user actions ...
recorder.stopRecording();
```

## Why ZMouse?

- **Zero dependencies** - Single binary, no runtime required
- **Type-safe API** - Domain error types, proper Zig idioms
- **Dual interface** - Interactive CLI and HTTP REST API
- **Library support** - Import as a module in your Zig projects
- **Recording support** - Capture and replay complex input sequences
- **Remote control** - Control from any device via HTTP API
