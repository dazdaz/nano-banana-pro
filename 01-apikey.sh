#!/usr/bin/env bash
# 01-apikey.sh – AIStudio Key Manager - Used by Nano Banana Pro key manager
# Features: Setup (Single Write + Explicit API List), Status, Audit, Interactive Delete

set -e

KEY_FILE="$HOME/.nano_banana_pro_key"
PROJECT_FILE="$HOME/.nano_banana_pro_project"

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

    # --- BILLING CHECK ---
    echo -e "${YELLOW}Checking billing configuration...${NC}"
    
    if gcloud beta billing projects describe "$PROJECT_ID" --format="value(billingEnabled)" 2>/dev/null | grep -iq true; then
        echo -e "  ${GREEN}Billing is active for this project.${NC}"
    else
        echo -e "  ${YELLOW}Project is not linked to an active billing account.${NC}"
        echo -e "  Searching for available billing accounts..."
        
        BILLING_ID=$(gcloud beta billing accounts list --filter="open:true" --format="value(name)" --limit=1 2>/dev/null)
        BILLING_NAME=$(gcloud beta billing accounts list --filter="open:true" --format="value(displayName)" --limit=1 2>/dev/null)

        if [ -z "$BILLING_ID" ]; then
            echo -e "  ${RED}Error: No open billing accounts found!${NC}"
            echo "  Please visit https://console.cloud.google.com/billing to create one."
            exit 1
        fi

        echo -e "  Found Account: ${CYAN}$BILLING_NAME${NC} (ID: $BILLING_ID)"
        echo -e "  Linking project '$PROJECT_ID' now..."
        
        if gcloud beta billing projects link "$PROJECT_ID" --billing-account="$BILLING_ID" --quiet >/dev/null 2>&1; then
            echo -e "  ${GREEN}Success: Project linked to billing.${NC}"
        else
            echo -e "  ${RED}Error: Failed to link billing. Check your permissions.${NC}"
            exit 1
        fi
    fi

    # --- API ENABLEMENT ---
    echo -e "${YELLOW}Enabling APIs:${NC}"
    echo "  - aiplatform.googleapis.com"
    echo "  - apikeys.googleapis.com"

    gcloud services enable aiplatform.googleapis.com apikeys.googleapis.com --project="$PROJECT_ID" --quiet >/dev/null 2>&1

    # --- KEY CREATION ---
    local DISPLAY_NAME="Nano Banana Pro – $(date +%s)"
    echo -e "${YELLOW}Creating API key...${NC}"
    
    local KEY_OUTPUT
    if KEY_OUTPUT=$(gcloud services api-keys create --display-name="$DISPLAY_NAME" --project="$PROJECT_ID" --format="value(response.keyString)" --quiet 2>&1); then
        if [[ "$KEY_OUTPUT" =~ AIza[0-9A-Za-z_-]+ ]]; then
             # Capture only first line
             KEY=$(echo "$KEY_OUTPUT" | grep -o 'AIza[0-9A-Za-z_-]\{35\}' | head -n 1)
        else
             KEY="$KEY_OUTPUT"
        fi
    else
         echo -e "${RED}Key creation failed.${NC}"
         echo "Output: $KEY_OUTPUT"
         exit 1
    fi

    if [ -z "$KEY" ]; then
        echo -e "${RED}Error: Key created but response was empty.${NC}"
        exit 1
    fi

    # --- SINGLE WRITE ---
    echo "$KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"

    # --- FINAL REPORT ---
    echo -e "\n${GREEN}=== SETUP COMPLETE ===${NC}"
    echo -e "Project ID:    ${YELLOW}$PROJECT_ID${NC}"
    echo -e "Key Name:      ${CYAN}$DISPLAY_NAME${NC}"
    echo -e "Key Content:   ${GREEN}$KEY${NC}"
    echo -e "Saved To:      $KEY_FILE"
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

    printf "%-45s %s\n" "DISPLAY NAME" "CREATED"
    echo "---------------------------------------------------------------------------"
    
    local FOUND_LOCAL=false

    # Fetch the list of keys (name and display name only)
    while IFS='|' read -r key_name display_name create_date; do
         [[ -z "$key_name" ]] && continue
         
         # Get the actual keyString by describing the specific key
         local key_str
         key_str=$(gcloud services api-keys get-key-string "$key_name" --project="$CURRENT_PROJ" 2>/dev/null | grep -o 'AIza[0-9A-Za-z_-]\{35\}' || echo "")
         
         if [ "$key_str" == "$LOCAL_KEY" ]; then
            printf "${GREEN}%-45s %s (ACTIVE)${NC}\n" "$display_name" "$create_date"
            FOUND_LOCAL=true
         else
            printf "%-45s %s\n" "$display_name" "$create_date"
         fi
    done < <(gcloud services api-keys list --project="$CURRENT_PROJ" --format="value[separator='|'](name,displayName,createTime)" --quiet 2>/dev/null)

    if [ "$FOUND_LOCAL" = false ] && [ -n "$LOCAL_KEY" ]; then
        echo; echo -e "${RED}WARNING: Your local key was NOT found in this cloud project!${NC}"
    fi
}

remove_key() {
    local CURRENT_PROJ=""; [ -f "$PROJECT_FILE" ] && CURRENT_PROJ=$(cat "$PROJECT_FILE")
    local LOCAL_KEY=""; [ -f "$KEY_FILE" ] && LOCAL_KEY=$(cat "$KEY_FILE")

    # Display local key file information
    echo -e "${CYAN}=== LOCAL KEY FILE ===${NC}"
    if [ -f "$KEY_FILE" ]; then
        echo -e "Path:   ${GREEN}$KEY_FILE${NC}"
        echo -e "Status: ${GREEN}Exists${NC}"
        echo -e "Key:    ${GREEN}$LOCAL_KEY${NC}"
    else
        echo -e "Path:   ${YELLOW}$KEY_FILE${NC}"
        echo -e "Status: ${RED}Does not exist${NC}"
    fi
    echo

    if [ -z "$CURRENT_PROJ" ]; then
        CURRENT_PROJ=$(gcloud config get-value project 2>/dev/null)
    fi

    if [ -n "$CURRENT_PROJ" ]; then
        echo -e "${YELLOW}Fetching ALL keys from project '$CURRENT_PROJ'...${NC}"
        
        declare -a key_names=()
        declare -a key_displays=()
        declare -a key_strings=()
        declare -a key_dates=()
        
        while IFS='|' read -r name display string date; do
            key_names+=("$name")
            key_displays+=("$display")
            key_strings+=("$string")
            key_dates+=("$date")
        done < <(gcloud services api-keys list --project="$CURRENT_PROJ" --format="value[separator='|'](name,displayName,keyString,createTime)" 2>/dev/null)

        # Check if we found any keys in the cloud
        if [ ${#key_names[@]} -gt 0 ]; then
            echo -e "\n${CYAN}Select a key to DELETE from Google Cloud:${NC}"
            local i=0
            for display in "${key_displays[@]}"; do
                local status_label="        "
                if [ "${key_strings[$i]}" == "$LOCAL_KEY" ]; then 
                    status_label="${GREEN}[ACTIVE]${NC}"
                fi
                printf "  ${YELLOW}%2d)${NC} %b %-35s ${CYAN}(Created: %s)${NC}\n" $((i+1)) "$status_label" "$display" "${key_dates[$i]}"
                ((i++))
            done
            echo -e "  ${YELLOW} L)${NC} Local Files Only (Keep Cloud Keys)"
            echo -e "  ${YELLOW} q)${NC} Quit (Do nothing)"
            echo

            read -r -p "$(echo -e "${YELLOW}Enter choice: ${NC}")" choice
            case "$choice" in
                q|Q) echo "Cancelled."; exit 0 ;;
                l|L) 
                    echo -e "${YELLOW}Removing local configuration files...${NC}"
                    if [ -f "$KEY_FILE" ]; then
                        echo -e "  Key File:     ${GREEN}$KEY_FILE${NC} (Exists)"
                    else
                        echo -e "  Key File:     ${YELLOW}$KEY_FILE${NC} (Not Found)"
                    fi
                    if [ -f "$PROJECT_FILE" ]; then
                        echo -e "  Project File: ${GREEN}$PROJECT_FILE${NC} (Exists)"
                    else
                        echo -e "  Project File: ${YELLOW}$PROJECT_FILE${NC} (Not Found)"
                    fi
                    rm -f "$KEY_FILE" "$PROJECT_FILE"
                    echo -e "${GREEN}Done.${NC}"
                    ;;
                *)
                    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $i ]; then
                        local idx=$((choice-1))
                        echo -e "${RED}Deleting ${key_displays[$idx]}...${NC}"
                        # Deleting cloud key
                        gcloud services api-keys delete "${key_names[$idx]}" --project="$CURRENT_PROJ" --quiet >/dev/null 2>&1
                        echo "Done."
                        
                        # Check if the user just deleted their ACTIVE local key
                        if [ "${key_strings[$idx]}" == "$LOCAL_KEY" ]; then
                            echo -e "${RED}WARNING: You just deleted the API Key that was saved locally!${NC}"
                            read -r -p "$(echo -e "${YELLOW}Do you want to remove the local files now? (y/N): ${NC}")" cleanup
                            if [[ "$cleanup" =~ ^[yY]$ ]]; then
                                [ -f "$KEY_FILE" ] && echo "  Removed: $KEY_FILE"
                                [ -f "$PROJECT_FILE" ] && echo "  Removed: $PROJECT_FILE"
                                rm -f "$KEY_FILE" "$PROJECT_FILE"
                                echo -e "${GREEN}Done.${NC}"
                            fi
                        fi
                    else
                        echo -e "${RED}Invalid selection.${NC}"; exit 1
                    fi
                    ;;
            esac
        else
            # Case: No keys found in cloud
            echo "No keys found in this cloud project."
            read -r -p "$(echo -e "${YELLOW}Remove local files? (y/N): ${NC}")" cleanup
            if [[ "$cleanup" =~ ^[yY]$ ]]; then
                [ -f "$KEY_FILE" ] && echo "  Removed: $KEY_FILE"
                [ -f "$PROJECT_FILE" ] && echo "  Removed: $PROJECT_FILE"
                rm -f "$KEY_FILE" "$PROJECT_FILE"
                echo -e "${GREEN}Done.${NC}"
            fi
        fi
    else
        echo -e "${RED}Could not determine project ID. Skipping cloud removal.${NC}"
    fi
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
