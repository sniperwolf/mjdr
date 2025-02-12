#!/bin/bash

# File: libs/colors.sh
# Description: Color definitions and basic utility functions
# This file should be sourced by other scripts

# ANSI color codes for output formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Debug mode flag (can be enabled with -d or --debug)
DEBUG=${DEBUG:-false}

# Function to print debug messages
# Args: $1 - message to print
debug_print() {
    if [ "$DEBUG" = true ]; then
        echo -e "${BLUE}[DEBUG] $1${NC}"
    fi
}

# Function to print error messages
# Args: $1 - message to print
error_print() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

# Function to print success messages
# Args: $1 - message to print
success_print() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# Function to print warning messages
# Args: $1 - message to print
warning_print() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Function to print info messages
# Args: $1 - message to print
info_print() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Function to print section headers
# Args: $1 - section title
print_section_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Function to print section footers
# Args: $1 - section title
print_section_footer() {
    echo -e "${BLUE}=== End of $1 ===${NC}\n"
}

# Function to handle script errors
# Args: $1 - error message, $2 - exit code (optional)
handle_error() {
    local message="$1"
    local exit_code="${2:-1}"

    error_print "$message"
    debug_print "Exit code: $exit_code"
    exit "$exit_code"
}

# Function to validate required commands
# Args: $@ - list of required commands
validate_commands() {
    local missing_commands=()

    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done

    if [ ${#missing_commands[@]} -ne 0 ]; then
        error_print "Required commands not found: ${missing_commands[*]}"
        return 1
    fi

    debug_print "All required commands are available: $*"
    return 0
}

# Function to parse command line arguments
# This function should be called from the main script
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--debug)
                DEBUG=true
                debug_print "Debug mode enabled"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                error_print "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Function to show help message
show_help() {
    cat << EOF
Usage: $0 [options]

Options:
  -d, --debug    Enable debug mode
  -h, --help     Show this help message

This script is part of the Jellyfin Docker management system.
For more information, please refer to the documentation.
EOF
}

# Function to check if script is sourced or executed directly
check_script_execution() {
    if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
        error_print "This script should be sourced, not executed directly."
        exit 1
    fi
}

# Execute check if script is sourced
check_script_execution

# Export all functions and variables
export RED GREEN BLUE YELLOW NC DEBUG
export -f debug_print error_print success_print warning_print info_print
export -f print_section_header print_section_footer handle_error
export -f validate_commands parse_arguments show_help