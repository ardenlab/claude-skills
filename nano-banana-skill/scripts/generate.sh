#!/bin/bash

# Nano Banana Image Generation Script
# Uses Google Gemini API via undyapi.com proxy

set -e

# Default values
PROMPT=""
INPUT_IMAGE=""
OUTPUT_DIR="./"
ASPECT_RATIO="1:1"
QUALITY="medium"
MODEL="flash"

# API endpoints (in order of priority)
API_ENDPOINTS=(
    "https://undyapi.com"
    "https://vip.undyingapi.com"
    "https://vip.undyingapi.site"
)

# Get model ID (using case instead of associative array for macOS compatibility)
get_model_id() {
    case "$1" in
        flash) echo "gemini-2.5-flash-image" ;;
        pro) echo "gemini-3-pro-image-preview" ;;
        *) echo "" ;;
    esac
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print usage
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Generate or edit images using Google Gemini's Nano Banana API.

OPTIONS:
    -p, --prompt TEXT       Text description for image generation (required)
    -i, --image PATH        Input image path for editing (optional)
    -o, --output DIR        Output directory (default: ./)
    -r, --ratio RATIO       Aspect ratio: 1:1, 16:9, 9:16, 4:3, 3:4 (default: 1:1)
    -q, --quality LEVEL     Quality: low, medium, high (default: medium)
    -m, --model MODEL       Model: flash, pro (default: flash)
    -h, --help              Show this help message

EXAMPLES:
    # Generate image from text
    $(basename "$0") -p "A cat in space" -o ./images

    # Edit existing image
    $(basename "$0") -p "Add a rainbow" -i photo.jpg -o ./edited

    # High quality with specific ratio
    $(basename "$0") -p "Landscape sunset" -r 16:9 -m pro -q high -o ./output

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--prompt)
            PROMPT="$2"
            shift 2
            ;;
        -i|--image)
            INPUT_IMAGE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -r|--ratio)
            ASPECT_RATIO="$2"
            shift 2
            ;;
        -q|--quality)
            QUALITY="$2"
            shift 2
            ;;
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            usage
            ;;
    esac
done

# Validate required parameters
if [[ -z "$PROMPT" ]]; then
    echo -e "${RED}Error: Prompt is required (-p)${NC}" >&2
    usage
fi

# Check API key
if [[ -z "$NANO_BANANA_API_KEY" ]]; then
    echo -e "${RED}Error: NANO_BANANA_API_KEY environment variable not set${NC}" >&2
    echo "Please set it with: export NANO_BANANA_API_KEY=\"your-api-key\"" >&2
    exit 1
fi

# Check required tools
for tool in curl jq base64; do
    if ! command -v "$tool" &> /dev/null; then
        echo -e "${RED}Error: Required tool '$tool' not found${NC}" >&2
        exit 1
    fi
done

# Validate model
MODEL_ID=$(get_model_id "$MODEL")
if [[ -z "$MODEL_ID" ]]; then
    echo -e "${RED}Error: Invalid model '$MODEL'. Use 'flash' or 'pro'${NC}" >&2
    exit 1
fi

# Validate aspect ratio
valid_ratios=("1:1" "16:9" "9:16" "4:3" "3:4")
if [[ ! " ${valid_ratios[*]} " =~ " ${ASPECT_RATIO} " ]]; then
    echo -e "${RED}Error: Invalid aspect ratio '$ASPECT_RATIO'${NC}" >&2
    echo "Valid options: ${valid_ratios[*]}" >&2
    exit 1
fi

# Validate quality
valid_qualities=("low" "medium" "high")
if [[ ! " ${valid_qualities[*]} " =~ " ${QUALITY} " ]]; then
    echo -e "${RED}Error: Invalid quality '$QUALITY'${NC}" >&2
    echo "Valid options: ${valid_qualities[*]}" >&2
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Build the prompt with aspect ratio hint
FULL_PROMPT="$PROMPT"
if [[ "$ASPECT_RATIO" != "1:1" ]]; then
    FULL_PROMPT="$PROMPT. Generate with aspect ratio $ASPECT_RATIO."
fi

# Build request JSON
build_request() {
    local parts_json=""

    # Add text prompt
    parts_json="{\"text\": $(echo "$FULL_PROMPT" | jq -Rs .)}"

    # Add image if provided
    if [[ -n "$INPUT_IMAGE" ]]; then
        if [[ ! -f "$INPUT_IMAGE" ]]; then
            echo -e "${RED}Error: Input image not found: $INPUT_IMAGE${NC}" >&2
            exit 1
        fi

        # Detect mime type
        local mime_type
        case "${INPUT_IMAGE##*.}" in
            jpg|jpeg|JPG|JPEG)
                mime_type="image/jpeg"
                ;;
            png|PNG)
                mime_type="image/png"
                ;;
            gif|GIF)
                mime_type="image/gif"
                ;;
            webp|WEBP)
                mime_type="image/webp"
                ;;
            *)
                echo -e "${RED}Error: Unsupported image format${NC}" >&2
                exit 1
                ;;
        esac

        # Encode image
        local image_base64
        if [[ "$(uname)" == "Darwin" ]]; then
            image_base64=$(base64 -i "$INPUT_IMAGE")
        else
            image_base64=$(base64 -w 0 "$INPUT_IMAGE")
        fi

        parts_json="$parts_json, {\"inline_data\": {\"mime_type\": \"$mime_type\", \"data\": \"$image_base64\"}}"
    fi

    cat << EOF
{
  "contents": [{
    "parts": [$parts_json]
  }],
  "generationConfig": {
    "responseModalities": ["TEXT", "IMAGE"]
  }
}
EOF
}

# Make API request
make_request() {
    local endpoint="$1"
    local url="${endpoint}/v1beta/models/${MODEL_ID}:generateContent"

    curl -s -X POST "$url" \
        -H "Content-Type: application/json" \
        -H "x-goog-api-key: $NANO_BANANA_API_KEY" \
        -d "$(build_request)"
}

# Try endpoints in order
echo -e "${YELLOW}Generating image...${NC}"
echo "Model: $MODEL_ID"
echo "Prompt: $PROMPT"
[[ -n "$INPUT_IMAGE" ]] && echo "Input: $INPUT_IMAGE"
echo "Aspect Ratio: $ASPECT_RATIO"
echo "Quality: $QUALITY"
echo ""

RESPONSE=""
for endpoint in "${API_ENDPOINTS[@]}"; do
    echo -e "Trying endpoint: $endpoint"
    RESPONSE=$(make_request "$endpoint" 2>/dev/null) || true

    # Check if response contains error
    if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
        error_msg=$(echo "$RESPONSE" | jq -r '.error.message // .error')
        echo -e "${YELLOW}Warning: $error_msg${NC}"
        continue
    fi

    # Check if response has candidates
    if echo "$RESPONSE" | jq -e '.candidates[0]' > /dev/null 2>&1; then
        break
    fi

    echo -e "${YELLOW}No valid response, trying next endpoint...${NC}"
done

# Check final response
if [[ -z "$RESPONSE" ]] || ! echo "$RESPONSE" | jq -e '.candidates[0]' > /dev/null 2>&1; then
    echo -e "${RED}Error: Failed to generate image from all endpoints${NC}" >&2
    echo "Response: $RESPONSE" >&2
    exit 1
fi

# Extract and save image
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="${OUTPUT_DIR}/nano_banana_${TIMESTAMP}.png"

# Extract text response if present
TEXT_RESPONSE=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[] | select(.text) | .text // empty' 2>/dev/null || true)

# Extract and decode image
IMAGE_DATA=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[] | select(.inlineData) | .inlineData.data // empty' 2>/dev/null || true)

if [[ -z "$IMAGE_DATA" ]]; then
    echo -e "${RED}Error: No image data in response${NC}" >&2
    exit 1
fi

# Decode and save
if [[ "$(uname)" == "Darwin" ]]; then
    echo "$IMAGE_DATA" | base64 -d -o "$OUTPUT_FILE"
else
    echo "$IMAGE_DATA" | base64 -d > "$OUTPUT_FILE"
fi

# Output results
echo ""
echo -e "${GREEN}Image generated successfully!${NC}"
echo "Output: $(realpath "$OUTPUT_FILE")"

if [[ -n "$TEXT_RESPONSE" ]]; then
    echo ""
    echo "Model response:"
    echo "$TEXT_RESPONSE"
fi
