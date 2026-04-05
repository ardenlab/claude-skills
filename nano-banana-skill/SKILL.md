---
name: nano-banana-skill
description: Generate and edit images using Google Gemini's Nano Banana image generation API via undyapi.com proxy. Use when users want to generate images from text descriptions, edit existing images with AI, or create visual content. Supports aspect ratio and quality control.
---

# Nano Banana Skill

A Claude Code Skill for AI-powered image generation and editing using Google Gemini's Nano Banana models.

## When to Use This Skill

Activate this skill when users request:
- Image generation from text descriptions
- AI image editing or modification
- Creating visual content with specific styles
- Generating images with custom aspect ratios

**Trigger phrases:**
- "Generate an image of..."
- "Create a picture of..."
- "Edit this image to..."
- "Make an image with..."
- "生成图片"
- "创建图片"
- "编辑图片"
- "AI 绘图"

---

## Prerequisites

1. **API Key**: Set environment variable `NANO_BANANA_API_KEY`
   ```bash
   export NANO_BANANA_API_KEY="your-api-key"
   ```

2. **Required tools**: `curl`, `jq`, `base64`

---

## Available Models

| Model | ID | Best For |
|-------|-----|----------|
| Flash | `gemini-3.1-flash-image-preview` | Fast generation, high volume, good quality |
| Pro | `gemini-3-pro-image-preview` | Professional quality, complex prompts |

---

## Quick Start

### Text to Image Generation

```bash
# Basic generation
bash ~/.claude/skills/nano-banana-skill/scripts/generate.sh \
  -p "A cute cat wearing a space helmet on Mars" \
  -o ./output

# With aspect ratio
bash ~/.claude/skills/nano-banana-skill/scripts/generate.sh \
  -p "A panoramic mountain landscape at sunset" \
  -o ./output \
  -r 16:9

# Using Pro model with 4K output
bash ~/.claude/skills/nano-banana-skill/scripts/generate.sh \
  -p "A detailed portrait of a robot philosopher" \
  -o ./output \
  -m pro \
  -s 4K
```

### Image Editing

```bash
# Edit an existing image
bash ~/.claude/skills/nano-banana-skill/scripts/generate.sh \
  -p "Add a rainbow in the sky" \
  -i ./input/photo.jpg \
  -o ./output

# Style transfer
bash ~/.claude/skills/nano-banana-skill/scripts/generate.sh \
  -p "Transform this photo into a watercolor painting" \
  -i ./input/photo.png \
  -o ./output \
  -m pro
```

---

## Parameters

| Parameter | Short | Description | Default |
|-----------|-------|-------------|---------|
| `--prompt` | `-p` | Text description (required) | - |
| `--image` | `-i` | Input image path for editing | - |
| `--output` | `-o` | Output directory | `./` |
| `--ratio` | `-r` | Aspect ratio (optional) | API default |
| `--size` | `-s` | Output image size (optional) | API default |
| `--model` | `-m` | Model: flash/pro | `flash` |

### Aspect Ratios

- `1:1` - Square
- `16:9` - Widescreen landscape
- `9:16` - Portrait (stories/reels)
- `4:3` - Standard landscape
- `3:4` - Standard portrait

### Output Image Sizes

- `1K` - 1024px
- `2K` - 2048px
- `4K` - 4096px (highest resolution)

---

## Examples

### 1. Generate a Logo

```bash
bash ~/.claude/skills/nano-banana-skill/scripts/generate.sh \
  -p "A minimalist logo for a coffee shop called 'Bean Dreams', modern flat design, warm colors" \
  -o ./logos \
  -r 1:1 \
  -m pro \
  -s 2K
```

### 2. Create Social Media Content

```bash
# Instagram post (square)
bash ~/.claude/skills/nano-banana-skill/scripts/generate.sh \
  -p "Aesthetic flat lay of coffee and pastries, soft morning light" \
  -o ./social \
  -r 1:1

# Instagram story (portrait)
bash ~/.claude/skills/nano-banana-skill/scripts/generate.sh \
  -p "Motivational quote background, gradient sunset colors" \
  -o ./social \
  -r 9:16
```

### 3. Edit Product Photos

```bash
bash ~/.claude/skills/nano-banana-skill/scripts/generate.sh \
  -p "Remove the background and add a professional studio backdrop" \
  -i ./product.jpg \
  -o ./edited \
  -m pro
```

### 4. Concept Art

```bash
bash ~/.claude/skills/nano-banana-skill/scripts/generate.sh \
  -p "Futuristic cyberpunk city street at night, neon lights reflecting on wet pavement, detailed concept art" \
  -o ./concept \
  -r 16:9 \
  -m pro \
  -s 4K
```

---

## API Endpoints

- **Primary**: `https://undyapi.com`
- **Backup 1**: `https://vip.undyingapi.com`
- **Backup 2**: `https://vip.undyingapi.site`

For detailed API documentation, see [REFERENCE.md](REFERENCE.md).

---

## Troubleshooting

### API Key Not Found
```
Error: NANO_BANANA_API_KEY environment variable not set
```
**Solution**: Export your API key: `export NANO_BANANA_API_KEY="your-key"`

### Rate Limited
```
Error: 429 Too Many Requests
```
**Solution**: Wait a moment and retry, or use the backup endpoints

### Invalid Image Format
```
Error: Unsupported image format
```
**Solution**: Supported formats are JPEG, PNG, GIF, WebP

---

## Best Practices

1. **Be specific in prompts**: Include style, mood, lighting, and composition details
2. **Use Pro model for text rendering**: Flash model may not render text accurately
3. **Choose appropriate aspect ratios**: Match the intended use case
4. **Start with medium quality**: Upgrade to high only when needed

---

## Output

Generated images are saved to the specified output directory with timestamped filenames:
- `nano_banana_20260109_143052.png`

The script also outputs:
- The full path to the generated image
- Any text response from the model (if applicable)
