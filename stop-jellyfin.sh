#!/bin/bash

# File: stop-jellyfin.sh
# Description: Script to stop Jellyfin Docker container
# Author: Fabrizio Fallico
# Version: 1.0.0

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load all library modules with absolute paths
# shellcheck source=./libs/colors.sh
source "${SCRIPT_DIR}/libs/colors.sh"
# shellcheck source=./libs/os_detect.sh
source "${SCRIPT_DIR}/libs/os_detect.sh"
# shellcheck source=./libs/docker.sh
source "${SCRIPT_DIR}/libs/docker.sh"
# shellcheck source=./libs/ui.sh
source "${SCRIPT_DIR}/libs/ui.sh"

# Default configuration file paths
readonly ENV_FILE="${SCRIPT_DIR}/.env"
readonly COMPOSE_FILE="${SCRIPT_DIR}/jd.yaml"

# Default container name if not set in environment
: "${CONTAINER_NAME:=jd}"

# Function to load environment variables
load_configuration() {
    if [ ! -f "$ENV_FILE" ]; then
        error_print "Environment file not found: ${ENV_FILE}"
        return 1
    fi

    # Load environment variables
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a

    # Validate required variables
    local -a required_vars=(
        "CONTAINER_NAME"
        "DOCKER_COMPOSE_FILE"
    )

    local missing_vars=0
    local var
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            error_print "Required variable not set: ${var}"
            missing_vars=1
        elif [ "$DEBUG" = true ]; then
            debug_print "${var} = ${!var}"
        fi
    done

    if [ "$missing_vars" -eq 1 ]; then
        return 1
    fi

    return 0
}

# Function to perform cleanup
cleanup() {
    if [ "$DEBUG" = true ]; then
        print_section_header "Cleanup"
        cleanup_docker
        success_print "Cleanup completed"
    fi
}

# Function to handle errors
handle_error() {
    local message="$1"
    local exit_code="${2:-1}"

    error_print "$message"

    if [ "$DEBUG" = true ]; then
        debug_print "Error occurred with exit code: ${exit_code}"
        debug_print "Script location: ${SCRIPT_DIR}"
        debug_print "Current working directory: $(pwd)"

        if command -v docker >/dev/null 2>&1; then
            debug_print "Docker status:"
            docker ps
        fi
    fi

    cleanup
    exit "$exit_code"
}

# Function to stop container and perform cleanup
stop_jellyfin() {
    print_section_header "Stopping Jellyfin"

    local status
    status=$(get_container_status "$CONTAINER_NAME")

    case "$status" in
        running)
            info_print "Stopping container..."
            if ! stop_container "$COMPOSE_FILE"; then
                handle_error "Failed to stop container"
            fi
            success_print "Container stopped successfully"
            ;;
        stopped)
            warning_print "Container is already stopped"
            if [ "$DEBUG" = true ]; then
                if ! docker rm "$CONTAINER_NAME"; then
                    warning_print "Failed to remove stopped container"
                fi
            fi
            ;;
        not_found)
            warning_print "Container not found"
            ;;
    esac

    return 0
}

# Function to show final status
show_final_status() {
    print_section_header "Final Status"

    local status
    status=$(get_container_status "$CONTAINER_NAME")
    show_service_status "Jellyfin" "$status"

    if [ "$DEBUG" = true ]; then
        debug_print "Container logs (last 5 lines):"
        docker logs "$CONTAINER_NAME" 2>&1 | tail -n 5 || true
    fi

    print_section_footer "Final Status"
}

# Main execution function
main() {
    # Clear screen and show banner
    clear_screen
    display_banner

    # Parse command line arguments
    parse_arguments "$@"

    # Show system information in debug mode
    if [ "$DEBUG" = true ]; then
        show_system_info
    fi

    # Load configuration
    if ! load_configuration; then
        handle_error "Failed to load configuration"
    fi

    # Check Docker status
    if ! check_docker_installation; then
        handle_error "Docker is not running or not installed properly"
    fi

    # Stop container
    if ! stop_jellyfin; then
        handle_error "Failed to stop Jellyfin"
    fi

    # Show final status
    show_final_status

    # Perform cleanup
    cleanup

    success_print "Jellyfin shutdown completed successfully!"
    return 0
}

# Error handler for script
trap 'handle_error "An error occurred. Check the logs for details." $?' ERR

# Execute main function
main "$@"
