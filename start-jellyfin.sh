#!/bin/bash

# File: start-jellyfin.sh
# Description: Main script for Jellyfin Docker container management
# Author: Fabrizio Fallico
# Version: 1.0.0

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load all library modules with absolute paths
# shellcheck source=./libs/colors.sh
source "${SCRIPT_DIR}/libs/colors.sh"
# shellcheck source=./libs/os_detect.sh
source "${SCRIPT_DIR}/libs/os_detect.sh"
# shellcheck source=./libs/network.sh
source "${SCRIPT_DIR}/libs/network.sh"
# shellcheck source=./libs/docker.sh
source "${SCRIPT_DIR}/libs/docker.sh"
# shellcheck source=./libs/filesystem.sh
source "${SCRIPT_DIR}/libs/filesystem.sh"
# shellcheck source=./libs/ui.sh
source "${SCRIPT_DIR}/libs/ui.sh"

# Default configuration file paths
readonly ENV_FILE="${SCRIPT_DIR}/.env"
readonly COMPOSE_FILE="${SCRIPT_DIR}/jd.yaml"

# Function to load environment variables
load_configuration() {
    print_section_header "Loading Configuration"

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
        "JELLYFIN_PORT"
        "DOCKER_COMPOSE_FILE"
        "USB_MOUNT_PATH"
        "MEDIA_PATH"
        "CONFIG_PATH"
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

    success_print "Configuration loaded successfully"
    return 0
}

# Function to perform initial setup checks
perform_setup_checks() {
    print_section_header "Performing Setup Checks"

    # Check system requirements
    if ! check_system_requirements; then
        return 1
    fi

    # Check Docker installation
    if ! check_docker_installation; then
        return 1
    fi

    # Check Docker Compose
    if ! check_docker_compose; then
        return 1
    fi

    # Validate compose file
    if ! validate_compose_file "$COMPOSE_FILE"; then
        return 1
    fi

    # Check filesystem
    local -a required_dirs=("$USB_MOUNT_PATH" "$MEDIA_PATH" "$CONFIG_PATH")
    if ! check_filesystem "${required_dirs[@]}"; then
        return 1
    fi

    success_print "All setup checks passed"
    return 0
}

# Function to prepare the environment
prepare_environment() {
    print_section_header "Preparing Environment"

    # Adapt paths for current OS
    adapt_paths

    # Create required directories
    if ! create_directory_structure "$USB_MOUNT_PATH" "media" "config"; then
        return 1
    fi

    # Set correct permissions
    if ! { set_permissions "$MEDIA_PATH" && set_permissions "$CONFIG_PATH"; }; then
        return 1
    fi

    success_print "Environment prepared successfully"
    return 0
}

# Function to manage container startup
manage_container() {
    print_section_header "Managing Container"

    # Get current container status
    local status
    status=$(get_container_status "$CONTAINER_NAME")

    case "$status" in
        running)
            warning_print "Container is already running"
            if get_confirmation "Would you like to restart it?"; then
                if ! stop_container "$COMPOSE_FILE"; then
                    return 1
                fi
                if ! start_container "$COMPOSE_FILE"; then
                    return 1
                fi
            else
                return 0
            fi
            ;;
        stopped)
            info_print "Found stopped container, removing it..."
            if ! docker rm "$CONTAINER_NAME"; then
                return 1
            fi
            if ! start_container "$COMPOSE_FILE"; then
                return 1
            fi
            ;;
        not_found)
            info_print "Starting new container..."
            if ! start_container "$COMPOSE_FILE"; then
                return 1
            fi
            ;;
    esac

    # Wait for container to be ready
    if ! wait_for_container "$CONTAINER_NAME" 60; then
        return 1
    fi

    success_print "Container management completed"
    return 0
}

# Function to display access information
show_access_info() {
    print_section_header "Access Information"

    # Get network information
    if ! get_network_info; then
        return 1
    fi

    # Display access URLs
    echo -e "\n${GREEN}Local Access:${NC}"
    echo "• http://localhost:${JELLYFIN_PORT}"

    echo -e "\n${GREEN}Network Access:${NC}"
    echo "• http://${PRIMARY_IP}:${JELLYFIN_PORT}"

    # Generate QR code for mobile access
    echo -e "\n${GREEN}Mobile Access (Scan QR Code):${NC}"
    display_qr_code "http://${PRIMARY_IP}:${JELLYFIN_PORT}"

    # Show container information if in debug mode
    if [ "$DEBUG" = true ]; then
        show_container_info "$CONTAINER_NAME"
    fi

    print_section_footer "Access Information"
}

# Function to perform cleanup
cleanup() {
    print_section_header "Cleanup"

    # Remove temporary files
    cleanup_temp_files

    # Clean old backups if any
    if [ -d "$BACKUP_DIR" ]; then
        clean_old_backups
    fi

    # Cleanup Docker resources if in debug mode
    if [ "$DEBUG" = true ]; then
        cleanup_docker
    fi

    success_print "Cleanup completed"
}

# Function to handle errors
handle_error() {
    local message="$1"
    local exit_code="${2:-1}"

    error_print "$message"

    if [ "$DEBUG" = true ]; then
        # Show additional debug information
        debug_print "Error occurred with exit code: ${exit_code}"
        debug_print "Script location: ${SCRIPT_DIR}"
        debug_print "Current working directory: $(pwd)"

        # Show Docker status if available
        if command -v docker >/dev/null 2>&1; then
            debug_print "Docker status:"
            docker ps
        fi
    fi

    # Perform cleanup before exit
    cleanup

    exit "$exit_code"
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

    # Perform setup checks
    if ! perform_setup_checks; then
        handle_error "Setup checks failed"
    fi

    # Prepare environment
    if ! prepare_environment; then
        handle_error "Environment preparation failed"
    fi

    # Manage container
    if ! manage_container; then
        handle_error "Container management failed"
    fi

    # Show access information
    show_access_info

    # Perform cleanup
    cleanup

    success_print "Jellyfin setup completed successfully!"
    return 0
}

# Error handler for script
trap 'handle_error "An error occurred. Check the logs for details." $?' ERR

# Execute main function
main "$@"
