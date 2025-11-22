#!/usr/bin/env bash
# ===============================================
# nano.sh - Generate images with Nano Banana Pro
# Requires: nano-key.sh to have saved a key
#
# Usage:
#   ./nano.sh "A cyberpunk banana wearing sunglasses, 4K"
#   ./nano.sh "Turn this photo into a Studio Ghibli scene" image.jpg
#   ./nano.sh --edit "Add a crown" photo.png
#   ./nano.sh --list                 # Show recent generations
# ===============================================

set -e

KEY_FILE="$HOME/.nano_banana_pro_key"
MODEL="gemini-3-pro-image-preview"
OUTPUT_DIR="$HOME/nano_banana_pro_outputs"
mkdir -p "$OUTPUT_DIR"

if [[ ! -f "$KEY_FILE" ]]; then
    echo -e "\033[0;31mNo API key found!\033[0m"
    echo "Run: ./nano-key.sh setup   (or)   ./nano-key.sh add \"your-key\""
    exit 1
fi

API_KEY=$(cat "$KEY_FILE")

generate() {
    PROMPT="$1"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    OUTPUT="$OUTPUT_DIR/nano_${TIMESTAMP}.png"

    echo -e "\033[1;33mGenerating with Nano Banana Pro...\033[0m"
    echo -e "Prompt: \033[0;32m$PROMPT\033[0m\n"

    python3 - <<EOF
import google.generativeai as genai, os, base64
genai.configure(api_key="$API_KEY")
model = genai.GenerativeModel("$MODEL")
response = model.generate_content("$PROMPT")
if not response.candidates:
    print("Blocked or error:", response.prompt_feedback)
    exit(1)
img_data = response.candidates[0].content.parts[0].inline_data.data
with open("$OUTPUT", "wb") as f:
    f.write(base64.b64decode(img_data))
print("Saved: $OUTPUT")
EOF

    echo -e "\n\033[0;32mSaved → $OUTPUT\033[0m"
    echo "Preview (macOS): open \"$OUTPUT\""
    echo "Preview (Linux): xdg-open \"$OUTPUT\" 2>/dev/null || echo \"Image saved\""
}

edit_image() {
    PROMPT="$1"
    IMAGE_PATH="$2"
    if [[ ! -f "$IMAGE_PATH" ]]; then
        echo "Image not found: $IMAGE_PATH"
        exit 1
    fi
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    OUTPUT="$OUTPUT_DIR/nano_edited_${TIMESTAMP}.png"

    echo -e "\033[1;33mEditing image with Nano Banana Pro...\033[0m"

    python3 - <<EOF
import google.generativeai as genai, base64
from google.generativeai.types import Part
genai.configure(api_key="$API_KEY")
model = genai.GenerativeModel("$MODEL")
with open("$IMAGE_PATH", "rb") as f:
    image_bytes = f.read()
image_part = Part.from_bytes(data=image_bytes, mime_type="image/png")
response = model.generate_content([image_part, "$PROMPT"])
img_data = response.candidates[0].content.parts[0].inline_data.data
with open("$OUTPUT", "wb") as f:
    f.write(base64.b64decode(img_data))
print("Edited → $OUTPUT")
EOF
}

list_recent() {
    echo -e "\033[1;34mRecent Nano Banana Pro generations:\033[0m"
    ls -la "$OUTPUT_DIR" | tail -20
}

case "$1" in
    --edit|-e)
        [[ -z "$3" ]] && echo "Usage: $0 --edit \"prompt\" image.jpg" && exit 1
        edit_image "$2" "$3"
        ;;
    --list|-l)
        list_recent
        ;;
    "")
        echo "Usage: $0 \"your prompt here\""
        echo "   or: $0 --edit \"prompt\" image.jpg"
        exit 1
        ;;
    *)
        generate "$*"
        ;;
esac
