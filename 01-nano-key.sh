#!/usr/bin/env bash
# 01-nano-key.sh – Nano Banana Pro key manager
# Features: Setup, Status (Full Paths), Audit (Full Paths), Interactive Delete (Cloud+Local)

set -e

KEY_FILE="$HOME/.nano_banana_pro_key"
PROJECT_FILE="$HOME/.nano_banana_pro_project"
MODEL="gemini-3-pro-image-preview"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- HELPER FUNCTIONS ---

select_project() {
    local chosen="$1"
    if [ -n "$chosen" ]; then
        if gcloud projects describe "$chosen" &>/dev/null; then
            echo "$chosen"; return
        else
            echo -e "${RED}Project '$chosen' not found${NC}" >&2; exit 1
        fi
    fi

    echo -e "${CYAN}Your Google Cloud projects:${NC}" >&2
    local counter=1
    local project_ids=()

    while IFS=, read -r proj_id proj_name; do
        [[ "$proj_name" == "Untitled project" ]] && proj_name="(no name)"
        printf "  ${YELLOW}%2d)${NC}  %-40s  ${GREEN}%s${NC}\n" "$counter" "$proj_id" "$proj_name" >&2
        project_ids+=("$proj_id")
        ((counter++))
    done < <(gcloud projects list --format="csv[no-heading](projectId,name)" --sort-by=projectId 2>/dev/null)

    if [ $counter -eq 1 ]; then echo -e "${RED}No projects found.${NC}" >&2; exit 1; fi

    echo >&2
    while true; do
        read -r -p "$(echo -e "${YELLOW}Enter number (1-$((counter-1)) or q to quit): ${NC}")" choice
        case "$choice" in
            q|Q) echo -e "${YELLOW}Cancelled.${NC}" >&2; return 1 ;;
            ''|*[!0-9]*) echo -e "${RED}Please type a number${NC}" >&2 ;;
            *)
                if [ "$choice" -ge 1 ] && [ "$choice" -lt "$counter" ] 2>/dev/null; then
                    echo "${project_ids[$((choice-1))]}"
                    return 0
                fi
                ;;
        esac
    done
}

# --- COMMANDS ---

setup() {
    if ! PROJECT_ID=$(select_project "${1:-}"); then exit 0; fi

    echo -e "\n${GREEN}Selected project → ${YELLOW}$PROJECT_ID${NC}\n"
    echo "$PROJECT_ID" > "$PROJECT_FILE"
    
    gcloud config set project "$PROJECT_ID" --quiet >/dev/null 2>&1

    echo -e "${YELLOW}Checking billing...${NC}"
    if ! gcloud beta billing projects describe "$PROJECT_ID" --format="value(billingEnabled)" 2>/dev/null | grep -q true; then
        echo "Enabling billing..."
        BILLING=$(gcloud beta billing accounts list --filter="open:true" --format="value(name)" --limit=1 --quiet 2>/dev/null)
        [ -z "$BILLING" ] && { echo -e "${RED}No billing account!${NC}"; exit 1; }
        gcloud beta billing projects link "$PROJECT_ID" --billing-account="$BILLING" --quiet >/dev/null 2>&1
    fi

    echo -e "${YELLOW}Enabling APIs...${NC}"
    gcloud services enable aiplatform.googleapis.com apikeys.googleapis.com --project="$PROJECT_ID" --quiet >/dev/null 2>&1

    local DISPLAY_NAME="Nano Banana Pro – $(date +%s)"
    echo -e "${YELLOW}Creating API key...${NC}"
    
    if ! gcloud services api-keys create --display-name="$DISPLAY_NAME" --project="$PROJECT_ID" --quiet >/dev/null 2>&1; then
         echo -e "${RED}Key creation failed.${NC}"; exit 1
    fi

    echo -e "${YELLOW}Waiting for key to appear...${NC}"
    local ATTEMPTS=0; local KEY=""
    while [ $ATTEMPTS -lt 5 ]; do
        KEY=$(gcloud services api-keys list --project="$PROJECT_ID" --filter="displayName:'$DISPLAY_NAME'" --format="value(keyString)" --limit=1 2>/dev/null)
        if [ -n "$KEY" ]; then break; fi
        sleep 2
        ((ATTEMPTS++))
    done

    if [ -z "$KEY" ]; then echo -e "${RED}Error: Retrieval timed out.${NC}"; exit 1; fi

    echo "$KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    echo -e "\n${GREEN}All set! Key saved to ${CYAN}$KEY_FILE${NC}"
}

add_key() { [ -z "${1:-}" ] && { echo -e "${RED}Usage: $0 add \"key\"${NC}"; exit 1; }; echo "$1" > "$KEY_FILE"; chmod 600 "$KEY_FILE"; echo -e "${GREEN}Key saved${NC}"; }

status() {
    echo -e "${CYAN}--- LOCAL SYSTEM STATUS ---${NC}"
    
    # 1. Key Info
    echo -e "${GREEN}Key File Path:${NC}     $KEY_FILE"
    if [ -f "$KEY_FILE" ]; then
        echo -e "${GREEN}Key Content:${NC}       $(cat "$KEY_FILE")"
    else
        echo -e "${RED}Key Content:${NC}       (File Missing)"
    fi

    # 2. Project Info
    echo -e "${GREEN}Project File Path:${NC} $PROJECT_FILE"
    if [ -f "$PROJECT_FILE" ]; then
        echo -e "${GREEN}Project ID:${NC}        $(cat "$PROJECT_FILE")"
    else
        local ACTIVE_PROJ
        ACTIVE_PROJ=$(gcloud config get-value project 2>/dev/null)
        echo -e "${YELLOW}Project ID:${NC}        (File Missing - Active: ${ACTIVE_PROJ:-None})"
    fi
    
    echo -e "${GREEN}Model:${NC}             ${YELLOW}$MODEL${NC}"
}

audit() { 
    local CURRENT_PROJ=""
    local LOCAL_KEY=""

    # 1. Local State
    echo -e "${CYAN}=== 1. LOCAL FILE SYSTEM ===${NC}"
    
    echo -e "Key File Path:     $KEY_FILE"
    if [ -f "$KEY_FILE" ]; then
        LOCAL_KEY=$(cat "$KEY_FILE")
        echo -e "Key Content:       ${GREEN}$LOCAL_KEY${NC}"
    else
        echo -e "Key Content:       ${RED}(Missing)${NC}"
    fi

    echo -e "Project File Path: $PROJECT_FILE"
    if [ -f "$PROJECT_FILE" ]; then
        CURRENT_PROJ=$(cat "$PROJECT_FILE")
        echo -e "Project ID:        ${YELLOW}$CURRENT_PROJ${NC}"
    else
        CURRENT_PROJ=$(gcloud config get-value project 2>/dev/null)
        if [ -n "$CURRENT_PROJ" ]; then
             echo -e "Fallback Config:   Using active gcloud project '${YELLOW}$CURRENT_PROJ${NC}'"
        else
             echo -e "${RED}Config:            No project determined. Cannot audit cloud.${NC}"
             return
        fi
    fi

    # 2. Cloud State
    echo
    echo -e "${CYAN}=== 2. GOOGLE CLOUD KEYS ($CURRENT_PROJ) ===${NC}"
    
    if ! gcloud services api-keys list --project="$CURRENT_PROJ" --limit=1 >/dev/null 2>&1; then
         echo -e "${RED}Error: Could not fetch keys.${NC} (Check permissions or project ID)"
         return
    fi

    printf "%-30s %-45s %s\n" "DISPLAY NAME" "KEY STRING" "CREATED"
    echo "---------------------------------------------------------------------------------------------"
    
    local FOUND_LOCAL=false

    while IFS=$'\t' read -r name key_str date; do
         [[ "$name" == "DISPLAY_NAME" ]] && continue
         
         if [ "$key_str" == "$LOCAL_KEY" ]; then
            printf "${GREEN}%-30s %-45s %s (ACTIVE)${NC}\n" "$name" "$key_str" "$date"
            FOUND_LOCAL=true
         else
            printf "%-30s %-45s %s\n" "$name" "$key_str" "$date"
         fi
    done < <(gcloud services api-keys list --project="$CURRENT_PROJ" --format="value[separator='	'](displayName, keyString, createTime)" 2>/dev/null)

    if [ "$FOUND_LOCAL" = false ] && [ -n "$LOCAL_KEY" ]; then
        echo; echo -e "${RED}WARNING: Your local key was NOT found in this cloud project!${NC}"
    fi
}

remove_key() {
    local CURRENT_PROJ=""; [ -f "$PROJECT_FILE" ] && CURRENT_PROJ=$(cat "$PROJECT_FILE")
    local LOCAL_KEY=""; [ -f "$KEY_FILE" ] && LOCAL_KEY=$(cat "$KEY_FILE")

    # Fallback if local project file is missing
    if [ -z "$CURRENT_PROJ" ]; then
        CURRENT_PROJ=$(gcloud config get-value project 2>/dev/null)
    fi

    if [ -n "$CURRENT_PROJ" ]; then
        echo -e "${YELLOW}Fetching ALL keys from project '$CURRENT_PROJ'...${NC}"
        
        declare -a key_names=()
        declare -a key_displays=()
        declare -a key_strings=()
        
        while IFS=$'\t' read -r name display string; do
            key_names+=("$name")
            key_displays+=("$display")
            key_strings+=("$string")
        done < <(gcloud services api-keys list --project="$CURRENT_PROJ" --format="value(name,displayName,keyString)" 2>/dev/null)

        if [ ${#key_names[@]} -gt 0 ]; then
            echo -e "\n${CYAN}Select a key to DELETE from Google Cloud:${NC}"
            local i=0
            for display in "${key_displays[@]}"; do
                local marker=" "
                if [ "${key_strings[$i]}" == "$LOCAL_KEY" ]; then marker="${GREEN}*${NC}"; fi
                printf "  ${YELLOW}%2d)${NC} %s %s\n" $((i+1)) "$marker" "$display"
                ((i++))
            done
            echo -e "  ${YELLOW} L)${NC} Local Files Only (Keep Cloud Keys)"
            echo -e "  ${YELLOW} q)${NC} Quit (Do nothing)"
            echo

            read -r -p "$(echo -e "${YELLOW}Enter choice: ${NC}")" choice
            case "$choice" in
                q|Q) echo "Cancelled."; exit 0 ;;
                l|L) ;; 
                *)
                    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $i ]; then
                        local idx=$((choice-1))
                        echo -e "${RED}Deleting ${key_displays[$idx]}...${NC}"
                        gcloud services api-keys delete "${key_names[$idx]}" --project="$CURRENT_PROJ" --quiet
                        echo "Done."
                    else
                        echo -e "${RED}Invalid selection.${NC}"; exit 1
                    fi
                    ;;
            esac
        else
            echo "No keys found in this cloud project."
        fi
    else
        echo -e "${RED}Could not determine project ID. Skipping cloud removal.${NC}"
    fi

    echo -e "${YELLOW}Removing local configuration files...${NC}"
    rm -f "$KEY_FILE" "$PROJECT_FILE"
    echo -e "${GREEN}Local files removed.${NC}"
}

show_project() { [ -f "$PROJECT_FILE" ] && cat "$PROJECT_FILE" || echo "unknown"; }

# --- MAIN SWITCH ---
case "${1:-}" in
    setup)        setup "${2:-}" ;;
    add)          shift; add_key "$1" ;;
    status)       status ;;
    show)         status ;; 
    audit)        audit ;;
    remove)       remove_key ;;
    project)      show_project ;;
    "")           echo "Usage: $0 setup | status | audit | remove | project"; exit 1 ;;
    *)            echo "Unknown command: $1"; exit 1 ;;
esac
