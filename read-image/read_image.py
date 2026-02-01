#!/usr/bin/env python3
"""
Read image content using vision model via OpenAI-compatible API.
Uses ANTHROPIC_BASE_URL and ANTHROPIC_AUTH_TOKEN environment variables.
Supports both local files and URLs.
"""

import os
import sys
import json
import base64
import mimetypes
import urllib.request
from io import BytesIO
from pathlib import Path
from urllib.parse import urlparse
from openai import OpenAI

# Pillow for image resizing (optional)
try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

# Max image size: 4MB after base64 (roughly 3MB raw)
MAX_IMAGE_BYTES = 3 * 1024 * 1024
# Max dimension for resize
MAX_DIMENSION = 2048


def is_url(path: str) -> bool:
    """Check if the given path is a URL."""
    result = urlparse(path)
    return result.scheme in ("http", "https")


def get_image_mime_type(image_path: str) -> str:
    """Get MIME type for an image file or URL."""
    mime_type, _ = mimetypes.guess_type(image_path)
    if mime_type is None:
        # Default to common image types based on extension
        ext = Path(urlparse(image_path).path).suffix.lower()
        mime_map = {
            ".jpg": "image/jpeg",
            ".jpeg": "image/jpeg",
            ".png": "image/png",
            ".gif": "image/gif",
            ".webp": "image/webp",
            ".bmp": "image/bmp",
        }
        mime_type = mime_map.get(ext, "image/png")
    return mime_type


def download_image(url: str) -> bytes:
    """Download image from URL and return raw bytes."""
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read()


def resize_image_if_needed(image_bytes: bytes, max_bytes: int = MAX_IMAGE_BYTES, max_dim: int = MAX_DIMENSION) -> tuple[bytes, str, bool]:
    """
    Resize image if it exceeds size limits.

    Args:
        image_bytes: Raw image bytes
        max_bytes: Maximum allowed size in bytes
        max_dim: Maximum dimension (width or height)

    Returns:
        Tuple of (processed_bytes, mime_type, was_resized)
    """
    if not HAS_PIL:
        # No Pillow, return as-is with a warning if too large
        return image_bytes, "image/jpeg", False

    img = Image.open(BytesIO(image_bytes))
    was_resized = False

    # Convert RGBA to RGB for JPEG
    if img.mode in ("RGBA", "P"):
        img = img.convert("RGB")

    # Resize if dimensions too large
    if img.width > max_dim or img.height > max_dim:
        ratio = min(max_dim / img.width, max_dim / img.height)
        new_size = (int(img.width * ratio), int(img.height * ratio))
        img = img.resize(new_size, Image.Resampling.LANCZOS)
        was_resized = True

    # Compress and check size
    quality = 85
    while quality >= 20:
        buffer = BytesIO()
        img.save(buffer, format="JPEG", quality=quality, optimize=True)
        result_bytes = buffer.getvalue()

        if len(result_bytes) <= max_bytes:
            return result_bytes, "image/jpeg", was_resized or quality < 85

        quality -= 10
        was_resized = True

    # Last resort: further resize
    while img.width > 512 or img.height > 512:
        img = img.resize((img.width // 2, img.height // 2), Image.Resampling.LANCZOS)
        buffer = BytesIO()
        img.save(buffer, format="JPEG", quality=60, optimize=True)
        result_bytes = buffer.getvalue()
        if len(result_bytes) <= max_bytes:
            return result_bytes, "image/jpeg", True

    # Give up, return what we have
    buffer = BytesIO()
    img.save(buffer, format="JPEG", quality=50, optimize=True)
    return buffer.getvalue(), "image/jpeg", True


def get_image_data(image_source: str) -> tuple[bytes, str, str, bool]:
    """
    Get image bytes from source (file or URL), resize if needed.

    Args:
        image_source: Local file path or URL

    Returns:
        Tuple of (image_bytes, mime_type, source_type, was_resized)
    """
    if is_url(image_source):
        raw_bytes = download_image(image_source)
        source_type = "url"
    else:
        with open(image_source, "rb") as f:
            raw_bytes = f.read()
        source_type = "local"

    # Check if resize needed (only process through PIL if image is too large)
    if len(raw_bytes) > MAX_IMAGE_BYTES:
        processed_bytes, mime_type, was_resized = resize_image_if_needed(raw_bytes)
        return processed_bytes, mime_type, source_type, was_resized

    mime_type = get_image_mime_type(image_source)
    return raw_bytes, mime_type, source_type, False


def read_image(
    image_source: str,
    prompt: str = "Describe this image in detail.",
    model: str = "read-image",
) -> dict:
    """
    Read and analyze an image using a vision model.

    Args:
        image_source: Path to local image file OR image URL (http/https)
        prompt: Question or instruction for the model
        model: Model name to use (default: read-image)

    Returns:
        dict with 'success', 'content' or 'error' keys
    """
    if is_url(image_source):
        resolved_source = image_source
    else:
        path = Path(image_source)
        if not path.exists():
            return {"success": False, "error": f"Image not found: {image_source}"}
        if not path.is_file():
            return {"success": False, "error": f"Not a file: {image_source}"}
        resolved_source = str(path.absolute())

    # Get environment variables
    base_url = os.environ.get("ANTHROPIC_BASE_URL")
    api_key = os.environ.get("ANTHROPIC_AUTH_TOKEN")

    if not base_url:
        return {"success": False, "error": "ANTHROPIC_BASE_URL environment variable not set"}

    if not api_key:
        return {"success": False, "error": "ANTHROPIC_AUTH_TOKEN environment variable not set"}

    base_url = base_url + "/v1"

    try:
        # Initialize OpenAI client with custom base URL
        client = OpenAI(base_url=base_url, api_key=api_key)

        # Get image data (handles both local files and URLs, with resize)
        image_bytes, mime_type, source_type, was_resized = get_image_data(resolved_source)
        base64_image = base64.standard_b64encode(image_bytes).decode("utf-8")
        image_url = f"data:{mime_type};base64,{base64_image}"

        # Create chat completion with vision
        response = client.chat.completions.create(
            model=model,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {"url": image_url},
                        },
                        {
                            "type": "text",
                            "text": prompt,
                        },
                    ],
                }
            ],
            max_tokens=4096,
        )

        # Extract response content
        content = response.choices[0].message.content
        usage = response.usage
        usage_data = {
            "prompt_tokens": usage.prompt_tokens if usage else None,
            "completion_tokens": usage.completion_tokens if usage else None,
            "total_tokens": usage.total_tokens if usage else None,
        }

        return {
            "success": True,
            "image_source": resolved_source,
            "source_type": source_type,
            "was_resized": was_resized,
            "prompt": prompt,
            "content": content,
            "model": model,
            "usage": usage_data,
        }

    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "error_type": type(e).__name__,
        }


def main():
    """CLI entry point."""
    if len(sys.argv) < 2:
        print(
            json.dumps(
                {
                    "success": False,
                    "error": "Usage: read_image.py <image_path_or_url> [prompt]",
                    "examples": [
                        "read_image.py /path/to/image.png",
                        "read_image.py https://example.com/image.jpg",
                        'read_image.py image.png "What text is in this image?"',
                    ],
                }
            )
        )
        sys.exit(1)

    image_source = sys.argv[1]
    prompt = sys.argv[2] if len(sys.argv) > 2 else "Describe this image in detail."

    result = read_image(image_source, prompt)
    print(json.dumps(result, ensure_ascii=False, indent=2))

    sys.exit(0 if result["success"] else 1)


if __name__ == "__main__":
    main()
