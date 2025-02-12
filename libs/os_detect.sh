#!/bin/bash

# File: libs/os_detect.sh
# Description: Operating System detection and system requirements check
# This file should be sourced by other scripts

# Load dependencies if not already loaded
if [ -z "$NC" ]; then
    # shellcheck source=./colors.sh
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi

# Global OS variables
OS=""
OS_VERSION=""
OS_ARCH=""

# Minimum system requirements - declare readonly only if not already declared
if [ -z "${REQUIRED_MEMORY_MB+x}" ]; then
    readonly REQUIRED_MEMORY_MB=1024
fi
if [ -z "${REQUIRED_DISK_SPACE_MB+x}" ]; then
    readonly REQUIRED_DISK_SPACE_MB=10240
fi
if [ -z "${REQUIRED_COMMANDS_LINUX+x}" ]; then
    readonly REQUIRED_COMMANDS_LINUX=("ip" "docker" "nc")
fi
if [ -z "${REQUIRED_COMMANDS_MACOS+x}" ]; then
    readonly REQUIRED_COMMANDS_MACOS=("ifconfig" "docker" "nc")
fi
if [ -z "${REQUIRED_COMMANDS_WINDOWS+x}" ]; then
    readonly REQUIRED_COMMANDS_WINDOWS=("ipconfig" "docker")
fi

# Function to detect the operating system
detect_os() {
    case "$(uname -s)" in
        Linux*)
            OS='Linux'
            if [ -f /etc/os-release ]; then
                # shellcheck source=/dev/null
                . /etc/os-release
                OS_VERSION="$VERSION_ID"
            fi
            ;;
        Darwin*)
            OS='MacOS'
            OS_VERSION=$(sw_vers -productVersion)
            ;;
        CYGWIN*|MINGW32*|MSYS*|MINGW*)
            OS='Windows'
            OS_VERSION=$(cmd /c ver | grep -o '[0-9].[0-9].[0-9]*')
            ;;
        *)
            OS='Unknown'
            error_print "Unsupported operating system: $(uname -s)"
            return 1
            ;;
    esac

    OS_ARCH=$(uname -m)

    debug_print "Detected OS: ${OS}"
    debug_print "OS Version: ${OS_VERSION}"
    debug_print "Architecture: ${OS_ARCH}"

    return 0
}

# Function to get system memory in MB
get_system_memory() {
    local total_memory

    case "$OS" in
        Linux)
            total_memory=$(free -m | awk '/Mem:/ {print $2}')
            ;;
        MacOS)
            total_memory=$(sysctl hw.memsize | awk '{print $2 / 1024 / 1024}')
            ;;
        Windows)
            total_memory=$(wmic computersystem get totalphysicalmemory | awk 'NR==2 {print $1 / 1024 / 1024}')
            ;;
        *)
            total_memory=0
            ;;
    esac

    printf "%.0f" "$total_memory"
}

# Function to check system requirements
check_system_requirements() {
    print_section_header "System Requirements Check"

    # Detect OS first
    if ! detect_os; then
        return 1
    fi

    # Check memory
    local available_memory
    available_memory=$(get_system_memory)
    if [ "$available_memory" -lt "$REQUIRED_MEMORY_MB" ]; then
        error_print "Insufficient memory: ${available_memory}MB (minimum ${REQUIRED_MEMORY_MB}MB required)"
        return 1
    fi
    success_print "Memory check passed: ${available_memory}MB available"

    # Check required commands based on OS
    local -a required_commands
    case "$OS" in
        Linux)
            required_commands=("${REQUIRED_COMMANDS_LINUX[@]}")
            ;;
        MacOS)
            required_commands=("${REQUIRED_COMMANDS_MACOS[@]}")
            ;;
        Windows)
            required_commands=("${REQUIRED_COMMANDS_WINDOWS[@]}")
            ;;
        *)
            error_print "Unsupported operating system"
            return 1
            ;;
    esac

    # Check each required command
    local missing_commands=0
    local cmd
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error_print "Required command not found: ${cmd}"
            missing_commands=1
        else
            debug_print "Found required command: ${cmd}"
        fi
    done

    if [ "$missing_commands" -eq 1 ]; then
        return 1
    fi

    # Check Docker Compose
    if ! docker compose version >/dev/null 2>&1; then
        error_print "Docker Compose V2 is not available"
        return 1
    fi
    success_print "Docker Compose check passed"

    # Additional OS-specific checks
    case "$OS" in
        Linux)
            # Check if running as root or have sudo access
            if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
                warning_print "Script may need root privileges for some operations"
            fi
            ;;
        MacOS)
            # Check if Docker Desktop is installed
            if [ ! -d "/Applications/Docker.app" ]; then
                warning_print "Docker Desktop not found in standard location"
            fi
            ;;
        Windows)
            # Check if running in WSL or Git Bash
            if [ ! -f "/proc/version" ] && [ ! -f "/usr/bin/cygpath" ]; then
                warning_print "Windows environment may need WSL or Git Bash"
            fi
            ;;
    esac

    success_print "All system requirements checks passed"
    return 0
}

# Function to adapt paths for current OS
adapt_paths() {
    case "$OS" in
        Windows)
            # Convert Windows paths to Docker-compatible paths
            if [[ "$USB_MOUNT_PATH" =~ ^[A-Za-z]: ]]; then
                USB_MOUNT_PATH="/$(echo "$USB_MOUNT_PATH" | sed 's/://' | sed 's/\\/\//g')"
            fi
            if [[ "$MEDIA_PATH" =~ ^[A-Za-z]: ]]; then
                MEDIA_PATH="/$(echo "$MEDIA_PATH" | sed 's/://' | sed 's/\\/\//g')"
            fi
            if [[ "$CONFIG_PATH" =~ ^[A-Za-z]: ]]; then
                CONFIG_PATH="/$(echo "$CONFIG_PATH" | sed 's/://' | sed 's/\\/\//g')"
            fi
            debug_print "Adapted Windows paths:"
            debug_print "USB_MOUNT_PATH: ${USB_MOUNT_PATH}"
            debug_print "MEDIA_PATH: ${MEDIA_PATH}"
            debug_print "CONFIG_PATH: ${CONFIG_PATH}"
            ;;
        *)
            debug_print "No path adaptation needed for ${OS}"
            ;;
    esac
}

# Function to get temporary directory path
get_temp_dir() {
    case "$OS" in
        Windows)
            echo "$TEMP"
            ;;
        *)
            echo "/tmp"
            ;;
    esac
}

# Execute check if script is sourced
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    error_print "This script should be sourced, not executed directly."
    exit 1
fi

# Export all functions and variables
export OS OS_VERSION OS_ARCH
export REQUIRED_MEMORY_MB REQUIRED_DISK_SPACE_MB
export -f detect_os get_system_memory check_system_requirements
export -f adapt_paths get_temp_dir
