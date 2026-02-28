# Nano Banana API Reference

## API Overview

Nano Banana is Google Gemini's native image generation capability, accessed through the undyapi.com proxy service for China mainland accessibility.

## Endpoints

### Base URLs

| Priority | URL | Region |
|----------|-----|--------|
| Primary | `https://undyapi.com` | China (direct) |
| Backup 1 | `https://vip.undyingapi.com` | China (partial) |
| Backup 2 | `https://vip.undyingapi.site` | China |

### Generate Content Endpoint

```
POST /v1beta/models/{model}:generateContent
```

**Models:**
- `gemini-3.1-flash-image-preview` - Fast, efficient, good quality
- `gemini-3-pro-image-preview` - Professional, advanced reasoning

---

## Request Format

### Headers

```http
Content-Type: application/json
x-goog-api-key: $NANO_BANANA_API_KEY
```

### Text to Image Request

```json
{
  "contents": [{
    "parts": [
      {"text": "Your image description here"}
    ]
  }],
  "generationConfig": {
    "responseModalities": ["TEXT", "IMAGE"]
  }
}
```

### Image Editing Request

```json
{
  "contents": [{
    "parts": [
      {"text": "Your editing instruction here"},
      {
        "inline_data": {
          "mime_type": "image/jpeg",
          "data": "<BASE64_ENCODED_IMAGE>"
        }
      }
    ]
  }],
  "generationConfig": {
    "responseModalities": ["TEXT", "IMAGE"]
  }
}
```

### With Aspect Ratio Control (Pro Model)

```json
{
  "contents": [{
    "parts": [
      {"text": "A landscape photo, aspect ratio 16:9"}
    ]
  }],
  "generationConfig": {
    "responseModalities": ["TEXT", "IMAGE"],
    "aspectRatio": "16:9"
  }
}
```

---

## Response Format

### Success Response

```json
{
  "candidates": [{
    "content": {
      "parts": [
        {
          "text": "Here's the generated image of..."
        },
        {
          "inlineData": {
            "mimeType": "image/png",
            "data": "<BASE64_ENCODED_IMAGE>"
          }
        }
      ],
      "role": "model"
    },
    "finishReason": "STOP"
  }],
  "usageMetadata": {
    "promptTokenCount": 10,
    "candidatesTokenCount": 100,
    "totalTokenCount": 110
  }
}
```

### Error Response

```json
{
  "error": {
    "code": 400,
    "message": "Invalid request",
    "status": "INVALID_ARGUMENT"
  }
}
```

---

## Supported Image Formats

### Input (for editing)
- JPEG (`image/jpeg`)
- PNG (`image/png`)
- GIF (`image/gif`)
- WebP (`image/webp`)

### Output
- PNG (`image/png`) - Default

---

## Generation Config Options

| Field | Type | Description |
|-------|------|-------------|
| `responseModalities` | array | Must include `"IMAGE"` for image generation |
| `aspectRatio` | string | `"1:1"`, `"16:9"`, `"9:16"`, `"4:3"`, `"3:4"` |
| `candidateCount` | integer | Number of images to generate (1-4) |

---

## Rate Limits

- Default: 60 requests per minute
- Burst: 10 requests per second

---

## Error Codes

| Code | Status | Description |
|------|--------|-------------|
| 400 | INVALID_ARGUMENT | Invalid request format or parameters |
| 401 | UNAUTHENTICATED | Invalid or missing API key |
| 403 | PERMISSION_DENIED | API key doesn't have access |
| 429 | RESOURCE_EXHAUSTED | Rate limit exceeded |
| 500 | INTERNAL | Server error |
| 503 | UNAVAILABLE | Service temporarily unavailable |

---

## cURL Examples

### Text to Image

```bash
curl -s -X POST \
  "https://undyapi.com/v1beta/models/gemini-3.1-flash-image-preview:generateContent" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: $NANO_BANANA_API_KEY" \
  -d '{
    "contents": [{
      "parts": [
        {"text": "A cute cat wearing a space helmet"}
      ]
    }],
    "generationConfig": {
      "responseModalities": ["TEXT", "IMAGE"]
    }
  }'
```

### Image Editing

```bash
# First, encode the image
IMAGE_BASE64=$(base64 -i input.jpg)

curl -s -X POST \
  "https://undyapi.com/v1beta/models/gemini-3.1-flash-image-preview:generateContent" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: $NANO_BANANA_API_KEY" \
  -d "{
    \"contents\": [{
      \"parts\": [
        {\"text\": \"Add a rainbow in the sky\"},
        {
          \"inline_data\": {
            \"mime_type\": \"image/jpeg\",
            \"data\": \"$IMAGE_BASE64\"
          }
        }
      ]
    }],
    \"generationConfig\": {
      \"responseModalities\": [\"TEXT\", \"IMAGE\"]
    }
  }"
```

---

## Safety & Watermarks

- All generated images include **SynthID** watermark (invisible)
- Content filtering is applied automatically
- Do not generate content that violates usage policies

---

## Best Practices

1. **Prompt Engineering**
   - Be specific about style, mood, lighting
   - Include composition details
   - Mention color preferences

2. **Model Selection**
   - Use Flash for quick iterations
   - Use Pro for final/production images
   - Pro is better for text rendering in images

3. **Error Handling**
   - Implement retry logic with exponential backoff
   - Use backup endpoints when primary fails

4. **Image Optimization**
   - Compress input images before encoding
   - Use appropriate aspect ratios for use case
