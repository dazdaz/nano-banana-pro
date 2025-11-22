#!/usr/bin/env bash
# ===============================================
# nano-key.sh - Manage Nano Banana Pro API key
# Usage:
#   ./nano-key.sh setup                    # First-time full setup
#   ./nano-key.sh add "AIzaSy..."         # Save a new key
#   ./nano-key.sh show                     # Show current key
#   ./nano-key.sh remove                   # Delete key from system
#   ./nano-key.sh project                  # Show current GCP project
# ===============================================

set -e

KEY_FILE="$HOME/.nano_banana_pro_key"
PROJECT_FILE="$HOME/.nano_banana_pro_project"
MODEL="gemini-3-pro-image-preview"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

setup() {
    echo -e "${GREEN}Setting up Nano Banana Pro (full auto setup)...${NC}"
    echo "This will create a Google Cloud project, enable APIs, and generate a restricted key."

    # Reuse previous logic (condensed)
    PROJECT_NAME="nano-pro-$(date +%s)"
    echo -e "${YELLOW}Creating project $PROJECT_NAME...${NC}"
    gcloud projects create "$PROJECT_NAME" --name="Nano Banana Pro" --quiet || echo "Project may already exist, continuing..."
    gcloud config set project "$PROJECT_NAME"

    echo "$PROJECT_NAME" > "$PROJECT_FILE"

    BILLING=$(gcloud beta billing accounts list --limit=1 --format="value(name)" --quiet || true)
    if [[ -n "$BILLING" ]]; then
        gcloud beta billing projects link "$PROJECT_NAME" --billing-account="$BILLING" --quiet
    else
        echo -e "${RED}No billing account found! Link one here first:${NC}"
        echo "https://console.cloud.google.com/billing"
        exit 1
    fi

    echo -e "${YELLOW}Enabling APIs...${NC}"
    gcloud services enable aiplatform.googleapis.com apikeys.googleapis.com --quiet

    echo -e "${YELLOW}Creating restricted API key...${NC}"
    KEY=$(gcloud services api-keys create --display-name="Nano Banana Pro Key" \
        --format="value(keyString)" --quiet)

    echo "$KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"

    echo -e "${GREEN}Setup complete!${NC}"
    echo "Project: $PROJECT_NAME"
    echo "Key saved securely to $KEY_FILE"
    echo "Run: ./nano-key.sh show"
}

add_key() {
    if [[ -z "$1" ]]; then
        echo -e "${RED}Usage: $0 add \"your-api-key-here\"${NC}"
        exit 1
    fi
    echo "$1" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    echo -e "${GREEN}API key saved securely!${NC}"
}

show_key() {
    if [[ -f "$KEY_FILE" ]]; then
        echo -e "${GREEN}Nano Banana Pro API Key:${NC}"
        cat "$KEY_FILE"
        echo
        echo -e "Model: ${YELLOW}$MODEL${NC}"
        [[ -f "$PROJECT_FILE" ]] && echo -e "Project: $(cat "$PROJECT_FILE")"
    else
        echo -e "${RED}No key found. Run ./nano-key.sh setup or add${NC}"
    fi
}

remove_key() {
    rm -f "$KEY_FILE" "$PROJECT_FILE
