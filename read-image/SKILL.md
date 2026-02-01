---
name: read-image
description: Use when the user asks to read, analyze, describe, or understand the content of an image file (local path or URL). Supports screenshots, photos, diagrams, charts, UI mockups, and any visual content.
---

# Read Image

Analyze image content using a vision model via OpenAI-compatible API. Supports local files and URLs.

## When to Use

- User asks "what's in this image/screenshot?"
- User provides an image path or URL and wants it described or analyzed
- Need to extract text (OCR), identify UI elements, read diagrams/charts
- User asks to compare or understand visual content

## Usage

Run `read_image.py` via Bash:

```bash
# Local file
python3 ~/.claude/skills/read-image/read_image.py /path/to/image.png "Describe this image"

# URL
python3 ~/.claude/skills/read-image/read_image.py "https://example.com/photo.jpg" "What text is in this image?"
```

**Arguments:**
1. `image_source` (required): Local file path or `http(s)://` URL
2. `prompt` (optional): Instruction for the model. Default: "Describe this image in detail."

**Output:** JSON with `success`, `content` (model response), `source_type` ("local"/"url"), `was_resized`, `usage`.

## Environment Variables

- `ANTHROPIC_BASE_URL` — API base URL (must end with `/v1`)
- `ANTHROPIC_AUTH_TOKEN` — API key

## Dependencies

- `openai` (required): `pip3 install openai`
- `Pillow` (optional but recommended): `pip3 install Pillow` — enables automatic image resizing for large files

## Image Processing

- Large images are automatically resized (max 2048px, max 3MB) via Pillow
- Only proportional scaling and JPEG quality compression — **never crops**
- URL images are downloaded to memory only, no temp files created
- Without Pillow, images are sent as-is

## Common Prompts

| Task | Prompt |
|------|--------|
| General description | `"Describe this image in detail."` |
| OCR / text extraction | `"Extract all text from this image."` |
| UI analysis | `"Describe the UI layout and components."` |
| Diagram reading | `"Explain the diagram and its relationships."` |
| Identify content | `"What is shown in this image?"` |
