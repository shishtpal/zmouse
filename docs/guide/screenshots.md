# Screenshots

ZMouse can capture screenshots via the HTTP API.

## Basic Screenshot

```bash
curl http://localhost:4000/api/screenshot > screenshot.bmp
```

Returns a BMP image of the entire primary screen.

## Base64 Screenshot

For embedding in JSON or HTML:

```bash
curl "http://localhost:4000/api/screenshot?base64"
```

Returns:

```json
{
  "image": "Qk1WQAAAAAAAD..."
}
```

Use in HTML:

```html
<img src="data:image/bmp;base64,Qk1WQAAAAAAAD..." />
```

## Response Format

| Format | Content-Type | Description |
|--------|--------------|-------------|
| Default | `image/bmp` | Binary BMP file |
| `?base64` | `application/json` | JSON with base64-encoded image |

## Example: JavaScript

```javascript
// Get screenshot as blob
async function getScreenshot() {
  const response = await fetch('http://localhost:4000/api/screenshot');
  const blob = await response.blob();
  return blob;
}

// Get as base64 for display
async function getScreenshotBase64() {
  const response = await fetch('http://localhost:4000/api/screenshot?base64');
  const data = await response.json();
  return `data:image/bmp;base64,${data.image}`;
}

// Display in an img element
const img = document.getElementById('screenshot');
img.src = await getScreenshotBase64();
```

## Example: Python

```python
import requests
import base64

# Save to file
response = requests.get('http://localhost:4000/api/screenshot')
with open('screenshot.bmp', 'wb') as f:
    f.write(response.content)

# Get as base64
response = requests.get('http://localhost:4000/api/screenshot?base64')
image_data = base64.b64decode(response.json()['image'])
```

## Technical Details

- Captures the primary monitor only
- Uses Win32 GDI for capture
- Output format is BMP (32-bit BGRA)
- No compression applied
