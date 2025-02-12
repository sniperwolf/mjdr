#!/bin/bash

# File: libs/filesystem.sh
# Description: Filesystem operations and management
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

# Filesystem configuration defaults
readonly DEFAULT_PERMISSIONS="755"
readonly MIN_DISK_SPACE_MB=10240  # 10GB in MB
readonly TEMP_PREFIX="jellyfin_tmp_"

# Function to check available disk space
# Args: $1 - path to check
# Returns: Available space in MB
check_disk_space() {
    local path="$1"
    local available_space

    case "$OS" in
        Linux)
            available_space=$(df -m "$path" | awk 'NR==2 {print $4}')
            ;;
        MacOS)
            available_space=$(df -m "$path" | awk 'NR==2 {print $4}')
            ;;
        Windows)
            # Convert Windows path for df command if using Git Bash
            local unix_path
            unix_path=$(echo "$path" | sed 's/\\/\//g' | sed 's/://')
            available_space=$(df -m "$unix_path" | awk 'NR==2 {print $4}')
            ;;
        *)
            error_print "Unsupported operating system for disk space check"
            return 1
            ;;
    esac

    debug_print "Available space at ${path}: ${available_space}MB"
    echo "$available_space"
}

# Function to verify directory exists and is writable
# Args: $1 - directory path
verify_directory() {
    local dir="$1"

    if [ ! -d "$dir" ]; then
        debug_print "Directory ${dir} does not exist, creating..."
        if ! mkdir -p "$dir"; then
            error_print "Failed to create directory: ${dir}"
            return 1
        fi
    fi

    if [ ! -w "$dir" ]; then
        error_print "Directory is not writable: ${dir}"
        return 1
    fi

    success_print "Directory verified: ${dir}"
    return 0
}

# Function to set correct permissions
# Args: $1 - path, $2 - permissions (optional)
set_permissions() {
    local path="$1"
    local perms="${2:-$DEFAULT_PERMISSIONS}"

    debug_print "Setting permissions ${perms} on ${path}"

    if ! chmod -R "$perms" "$path" 2>/dev/null; then
        error_print "Failed to set permissions on: ${path}"
        return 1
    fi

    return 0
}

# Function to create required directory structure
# Args: $1 - base path, $@ - subdirectories
create_directory_structure() {
    local base_path="$1"
    shift
    local subdirs=("$@")

    # Check base path
    if ! verify_directory "$base_path"; then
        return 1
    fi

    # Create subdirectories
    local dir
    for dir in "${subdirs[@]}"; do
        local full_path="${base_path}/${dir}"
        if ! verify_directory "$full_path"; then
            return 1
        fi
        set_permissions "$full_path"
    done

    return 0
}

# Function to cleanup temporary files
cleanup_temp_files() {
    local temp_dir

    case "$OS" in
        Windows)
            temp_dir="$TEMP"
            ;;
        *)
            temp_dir="/tmp"
            ;;
    esac

    debug_print "Cleaning temporary files in ${temp_dir}"

    if [ -d "$temp_dir" ]; then
        find "$temp_dir" -name "${TEMP_PREFIX}*" -type f -mtime +1 -delete 2>/dev/null
        success_print "Temporary files cleaned"
    else
        warning_print "Temporary directory not found: ${temp_dir}"
    fi
}

# Function to check and prepare filesystem
check_filesystem() {
    local -a required_dirs=("$@")
    local space_ok=true

    print_section_header "Filesystem Check"

    # Check disk space for each directory
    local dir
    for dir in "${required_dirs[@]}"; do
        local available_space
        available_space=$(check_disk_space "$dir")
        if [ "$available_space" -lt "$MIN_DISK_SPACE_MB" ]; then
            error_print "Insufficient disk space for ${dir}"
            error_print "Required: ${MIN_DISK_SPACE_MB}MB, Available: ${available_space}MB"
            space_ok=false
        fi
    done

    if ! $space_ok; then
        return 1
    fi

    # Verify and create directories
    for dir in "${required_dirs[@]}"; do
        if ! verify_directory "$dir"; then
            return 1
        fi
    done

    success_print "Filesystem check completed successfully"
    return 0
}

# Execute check if script is sourced
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    error_print "This script should be sourced, not executed directly."
    exit 1
fi

# Export all functions and variables
export DEFAULT_PERMISSIONS MIN_DISK_SPACE_MB TEMP_PREFIX
export -f check_disk_space verify_directory set_permissions
export -f create_directory_structure cleanup_temp_files check_filesystem
