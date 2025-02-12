#!/bin/bash

# File: libs/ui.sh
# Description: User interface and display functions
# This file should be sourced by other scripts

# Load dependencies if not already loaded
if [ -z "$NC" ]; then
    # shellcheck source=./colors.sh
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi
if [ -z "$OS" ]; then
    # shellcheck source=./os_detect.sh
    source "$(dirname "${BASH_SOURCE[0]}")/os_detect.sh"
fi

# UI Configuration
readonly UI_WIDTH=80
readonly SPINNER_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
readonly BANNER_FILE="banner.txt"

# Function to clear screen based on OS
clear_screen() {
    case "$OS" in
        Windows)
            cmd.exe /c cls
            ;;
        *)
            clear
            ;;
    esac
}

# Function to display banner
display_banner() {
    if [ -f "$BANNER_FILE" ]; then
        while IFS= read -r line; do
            echo "$line"
        done < "$BANNER_FILE"
    else
        echo -e "${BLUE}"
        echo "=============================="
        echo "      Jellyfin Manager       "
        echo "=============================="
        echo -e "${NC}"
    fi
}

# Function to display spinner
# Args: $1 - process ID to monitor
show_spinner() {
    local pid="$1"
    local delay=0.1
    local spinstr="$SPINNER_CHARS"

    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r[%c] " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep "$delay"
    done
    printf "\r"
}

# Function to display progress bar
# Args: $1 - current value, $2 - max value
show_progress() {
    local current="$1"
    local max="$2"
    local percent=$((current * 100 / max))
    local filled=$((percent * UI_WIDTH / 100))
    local empty=$((UI_WIDTH - filled))

    printf "\r["
    printf "%${filled}s" '' | tr ' ' '='
    printf "%${empty}s" '' | tr ' ' ' '
    printf "] %d%%" "$percent"
}

# Function to get user confirmation
# Args: $1 - prompt message
# Returns: 0 for yes, 1 for no
get_confirmation() {
    local prompt="${1:-Continue?}"
    local response

    while true; do
        echo -en "${YELLOW}${prompt} [y/n]: ${NC}"
        read -r response
        case "$response" in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes (y) or no (n).";;
        esac
    done
}

# Function to display menu
# Args: $1 - title, $@ - menu options
show_menu() {
    local title="$1"
    shift
    local -a options=("$@")
    local choice

    print_section_header "$title"

    local i
    for i in "${!options[@]}"; do
        echo "$((i+1)). ${options[$i]}"
    done
    echo "q. Quit"

    while true; do
        echo -en "\n${YELLOW}Select an option: ${NC}"
        read -r choice

        if [[ "$choice" == "q" ]]; then
            return 255
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le "${#options[@]}" ]; then
            return $((choice-1))
        fi

        echo "Invalid option. Please try again."
    done
}

# Function to get user input with validation
# Args: $1 - prompt, $2 - validation regex (optional)
get_user_input() {
    local prompt="$1"
    local regex="$2"
    local input

    while true; do
        echo -en "${YELLOW}${prompt}: ${NC}"
        read -r input

        if [ -z "$regex" ] || [[ "$input" =~ $regex ]]; then
            echo "$input"
            return 0
        fi

        echo "Invalid input. Please try again."
    done
}

# Function to display error message with optional retry
# Args: $1 - error message, $2 - allow retry (true/false)
show_error() {
    local message="$1"
    local allow_retry="${2:-false}"

    error_print "$message"

    if [ "$allow_retry" = true ] && get_confirmation "Would you like to retry?"; then
        return 0
    fi

    return 1
}

# Function to generate and display QR code
# Args: $1 - content
display_qr_code() {
    local content="$1"

    if ! command -v qrencode >/dev/null 2>&1; then
        warning_print "qrencode not installed. QR code generation not available."
        echo "Content: ${content}"
        return 1
    fi

    qrencode -t ANSI "$content"
}

# Function to display service status
# Args: $1 - service name, $2 - status (running/stopped/error)
show_service_status() {
    local service="$1"
    local status="$2"
    local status_color

    case "$status" in
        running)
            status_color="$GREEN"
            ;;
        stopped)
            status_color="$YELLOW"
            ;;
        error)
            status_color="$RED"
            ;;
        *)
            status_color="$NC"
            ;;
    esac

    printf "${BLUE}%-20s${NC} [${status_color}%-10s${NC}]\n" "$service" "$status"
}

# Function to display system information
show_system_info() {
    print_section_header "System Information"

    echo -e "${BLUE}Operating System:${NC} ${OS}"
    echo -e "${BLUE}OS Version:${NC} ${OS_VERSION}"
    echo -e "${BLUE}Architecture:${NC} ${OS_ARCH}"

    local memory
    memory=$(get_system_memory)
    echo -e "${BLUE}Available Memory:${NC} ${memory}MB"

    if [ -n "$PRIMARY_IP" ]; then
        echo -e "${BLUE}Primary IP:${NC} ${PRIMARY_IP}"
        echo -e "${BLUE}Network Interface:${NC} ${PRIMARY_INTERFACE} (${PRIMARY_TYPE})"
    fi

    print_section_footer "System Information"
}

# Execute check if script is sourced
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    error_print "This script should be sourced, not executed directly."
    exit 1
fi

# Export all functions and variables
export UI_WIDTH SPINNER_CHARS BANNER_FILE
export -f clear_screen display_banner show_spinner show_progress
export -f get_confirmation show_menu get_user_input show_error
export -f display_qr_code show_service_status show_system_info