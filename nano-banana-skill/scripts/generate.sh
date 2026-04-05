#!/bin/bash

# Nano Banana Image Generation Script
# Uses Google Gemini API via undyapi.com proxy

set -e

# Default values
PROMPT=""
INPUT_IMAGE=""
OUTPUT_DIR="./"
ASPECT_RATIO=""
IMAGE_SIZE=""
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
        flash) echo "gemini-3.1-flash-image-preview" ;;
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
    -r, --ratio RATIO       Aspect ratio (model-specific, see docs)
    -s, --size SIZE         Output image size: 512 (flash only), 1K, 2K, 4K
    -m, --model MODEL       Model: flash, pro (default: flash)
    -h, --help              Show this help message

EXAMPLES:
    # Generate image from text
    $(basename "$0") -p "A cat in space" -o ./images

    # Edit existing image
    $(basename "$0") -p "Add a rainbow" -i photo.jpg -o ./edited

    # High quality 4K with specific ratio
    $(basename "$0") -p "Landscape sunset" -r 16:9 -s 4K -m pro -o ./output

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
        -s|--size)
            IMAGE_SIZE="$2"
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

# Validate aspect ratio (if specified, model-specific)
if [[ -n "$ASPECT_RATIO" ]]; then
    if [[ "$MODEL" == "flash" ]]; then
        valid_ratios=("1:1" "1:4" "1:8" "2:3" "3:2" "3:4" "4:1" "4:3" "4:5" "5:4" "8:1" "9:16" "16:9" "21:9")
    else
        valid_ratios=("1:1" "2:3" "3:2" "3:4" "4:3" "4:5" "5:4" "9:16" "16:9" "21:9")
    fi
    if [[ ! " ${valid_ratios[*]} " =~ " ${ASPECT_RATIO} " ]]; then
        echo -e "${RED}Error: Invalid aspect ratio '$ASPECT_RATIO' for $MODEL model${NC}" >&2
        echo "Valid options: ${valid_ratios[*]}" >&2
        exit 1
    fi
fi

# Validate image size (if specified, model-specific)
if [[ -n "$IMAGE_SIZE" ]]; then
    if [[ "$MODEL" == "flash" ]]; then
        valid_sizes=("512" "1K" "2K" "4K")
    else
        valid_sizes=("1K" "2K" "4K")
    fi
    if [[ ! " ${valid_sizes[*]} " =~ " ${IMAGE_SIZE} " ]]; then
        echo -e "${RED}Error: Invalid image size '$IMAGE_SIZE' for $MODEL model${NC}" >&2
        echo "Valid options: ${valid_sizes[*]}" >&2
        exit 1
    fi
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Build request JSON (OpenAI-compatible with extra_body for Google params)
build_request() {
    # Build message content
    local content=""
    if [[ -n "$INPUT_IMAGE" ]]; then
        if [[ ! -f "$INPUT_IMAGE" ]]; then
            echo -e "${RED}Error: Input image not found: $INPUT_IMAGE${NC}" >&2
            exit 1
        fi

        # Detect mime type
        local mime_type
        case "${INPUT_IMAGE##*.}" in
            jpg|jpeg|JPG|JPEG) mime_type="image/jpeg" ;;
            png|PNG)           mime_type="image/png" ;;
            gif|GIF)           mime_type="image/gif" ;;
            webp|WEBP)         mime_type="image/webp" ;;
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

        content="[{\"type\": \"text\", \"text\": $(echo "$PROMPT" | jq -Rs .)}, {\"type\": \"image_url\", \"image_url\": {\"url\": \"data:${mime_type};base64,${image_base64}\"}}]"
    else
        content="$(echo "$PROMPT" | jq -Rs .)"
    fi

    # Build image_config (only when optional fields are set)
    local image_config=""
    if [[ -n "$IMAGE_SIZE" ]] || [[ -n "$ASPECT_RATIO" ]]; then
        local config_fields=""
        if [[ -n "$IMAGE_SIZE" ]]; then
            config_fields="\"image_size\": \"$IMAGE_SIZE\""
        fi
        if [[ -n "$ASPECT_RATIO" ]]; then
            [[ -n "$config_fields" ]] && config_fields="$config_fields, "
            config_fields="${config_fields}\"aspect_ratio\": \"$ASPECT_RATIO\""
        fi
        image_config=",
        \"image_config\": {$config_fields}"
    fi

    cat << EOF
{
  "model": "$MODEL_ID",
  "messages": [{"role": "user", "content": $content}],
  "extra_body": {
    "google": {
      "response_modalities": ["TEXT", "IMAGE"]${image_config}
    }
  }
}
EOF
}

# Make API request (OpenAI-compatible endpoint)
make_request() {
    local endpoint="$1"
    local url="${endpoint}/v1/chat/completions"

    curl -s -X POST "$url" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $NANO_BANANA_API_KEY" \
        -d "$(build_request)"
}

# Try endpoints in order
echo -e "${YELLOW}Generating image...${NC}"
echo "Model: $MODEL_ID"
echo "Prompt: $PROMPT"
[[ -n "$INPUT_IMAGE" ]] && echo "Input: $INPUT_IMAGE"
[[ -n "$ASPECT_RATIO" ]] && echo "Aspect Ratio: $ASPECT_RATIO"
[[ -n "$IMAGE_SIZE" ]] && echo "Image Size: $IMAGE_SIZE"
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

    # Check if response has choices
    if echo "$RESPONSE" | jq -e '.choices[0]' > /dev/null 2>&1; then
        break
    fi

    echo -e "${YELLOW}No valid response, trying next endpoint...${NC}"
done

# Check final response
if [[ -z "$RESPONSE" ]] || ! echo "$RESPONSE" | jq -e '.choices[0]' > /dev/null 2>&1; then
    echo -e "${RED}Error: Failed to generate image from all endpoints${NC}" >&2
    echo "Response: $RESPONSE" >&2
    exit 1
fi

# Extract content (format: text + ![image](data:mime;base64,DATA))
CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null || true)

if [[ -z "$CONTENT" ]]; then
    echo -e "${RED}Error: No content in response${NC}" >&2
    exit 1
fi

# Extract text (everything before the image markdown)
TEXT_RESPONSE=$(echo "$CONTENT" | sed 's/!\[image\](data:image\/[^)]*)//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

# Extract mime type and base64 data from ![image](data:mime;base64,DATA)
MIME_TYPE=$(echo "$CONTENT" | grep -oP 'data:\K(image/[^;]+)' 2>/dev/null || echo "$CONTENT" | sed -n 's/.*data:\(image\/[^;]*\);base64,.*/\1/p')
IMAGE_DATA=$(echo "$CONTENT" | sed -n 's/.*base64,\([^)]*\)).*/\1/p')

if [[ -z "$IMAGE_DATA" ]]; then
    echo -e "${RED}Error: No image data in response${NC}" >&2
    exit 1
fi

# Determine file extension from mime type
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
case "$MIME_TYPE" in
    image/jpeg) EXT="jpg" ;;
    image/png)  EXT="png" ;;
    image/gif)  EXT="gif" ;;
    image/webp) EXT="webp" ;;
    *)          EXT="jpg" ;;
esac
OUTPUT_FILE="${OUTPUT_DIR}/nano_banana_${TIMESTAMP}.${EXT}"

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
