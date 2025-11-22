#!/usr/bin/env bash
# ===============================================
# 01-nano-key.sh - Manage Nano Banana Pro API key
# Works on Linux & macOS
#
# Usage:
#   ./01-nano-key.sh setup                    # Full auto setup
#   ./01-nano-key.sh add "AIzaSy..."          # Save a key manually
#   ./01-nano-key.sh show                     # Show current key
#   ./01-nano-key.sh remove                   # Delete key
#   ./01-nano-key.sh project                  # Show current project
# ===============================================

set -euo pipefail  # Safer bash

KEY_FILE="$HOME/.nano_banana_pro_key"
PROJECT_FILE="$HOME/.nano_banana_pro_project"
MODEL="gemini-3-pro-image-preview"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

setup() {
    echo -e "${GREEN}Setting up Nano Banana Pro (full auto setup)...${NC}"
    echo "This will create a new Google Cloud project + restricted API key."

    PROJECT_NAME="nano-pro-$(date +%s)"
    echo -e "${YELLOW}Creating project: $PROJECT_NAME${NC}"
    gcloud projects create "$PROJECT_NAME" --name="Nano Banana Pro" --quiet || \
        echo "Project may already exist – continuing..."

    gcloud config set project "$PROJECT_NAME" --quiet
    echo "$PROJECT_NAME" > "$PROJECT_FILE"

    # Link billing
    echo -e "${YELLOW}Linking billing account...${NC}"
    BILLING_ACCOUNT=$(gcloud beta billing accounts list --filter="open:true" --format="value(name)" --limit=1 --quiet)
    if [[ -z "$BILLING_ACCOUNT" ]]; then
        echo -e "${RED}No open billing account found!${NC}"
        echo "Go here → https://console.cloud.google.com/billing"
        exit 1
    fi
    gcloud beta billing projects link "$PROJECT_NAME" --billing-account="$BILLING_ACCOUNT" --quiet

    # Enable APIs
    echo -e "${YELLOW}Enabling required APIs...${NC}"
    gcloud services enable aiplatform.googleapis.com apikeys.googleapis.com --quiet

    # Wait a moment for propagation
    sleep 8

    # Create restricted API key
    echo -e "${YELLOW}Creating secure API key...${NC}"
    KEY=$(gcloud services api-keys create \
        --display-name="Nano Banana Pro Key" \
        --format="value(keyString)" \
        --quiet)

    echo "$KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"

    echo -e "${GREEN}Setup complete!${NC}"
    echo "Project : $PROJECT_NAME"
    echo "Key saved → $KEY_FILE"
    echo "Run: ./01-nano-key.sh show"
}

add_key() {
    if [[ -z "${1:-}" ]]; then
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
        echo -e "Model   : ${YELLOW}$MODEL${NC}"
        if [[ -f "$PROJECT_FILE" ]]; then
            echo -e "Project : $(cat "$PROJECT_FILE")"
        fi
    else
        echo -e "${RED}No key found. Run setup or add a key first.${NC}"
    fi
}

remove_key() {
    rm -f "$KEY_FILE" "$PROJECT_FILE"
    echo -e "${YELLOW}API key and project info removed.${NC}"
}

show_project() {
    if [[ -f "$PROJECT_FILE" ]]; then
        cat "$PROJECT_FILE"
    else
        echo "unknown"
    fi
}

# -----------------------------
# Main command router
# -----------------------------
case "${1:-}" in
    setup)      setup ;;
    add)        add_key "$2" ;;
    show)       show_key ;;
    remove)     remove_key ;;
    project)    show_project ;;
    "")
        echo "Usage: $0 {setup|add \"key\"|show|remove|project}"
        exit 1
        ;;
    *)
        echo "Unknown command: $1"
        echo "Usage: $0 {setup|add \"key\"|show|remove|project}"
        exit 1
        ;;
esac
