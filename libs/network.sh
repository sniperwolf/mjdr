#!/bin/bash

# File: libs/network.sh
# Description: Network detection and management functions
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

# Global network variables
PRIMARY_IP=""
PRIMARY_INTERFACE=""
PRIMARY_TYPE=""
NETWORK_INTERFACES_IP=""
NETWORK_INTERFACES_TYPE=""
NETWORK_INTERFACES_SPEED=""

# Function to store interface information
# Args: $1 - interface name, $2 - type, $3 - ip, $4 - speed
store_interface_info() {
    local interface="$1"
    local type="$2"
    local ip="$3"
    local speed="$4"

    NETWORK_INTERFACES_IP="${NETWORK_INTERFACES_IP};${interface}:${ip}"
    NETWORK_INTERFACES_TYPE="${NETWORK_INTERFACES_TYPE};${interface}:${type}"
    NETWORK_INTERFACES_SPEED="${NETWORK_INTERFACES_SPEED};${interface}:${speed}"
}

# Function to get stored interface information
# Args: $1 - interface name, $2 - info type (ip/type/speed)
get_interface_info() {
    local interface="$1"
    local info_type="$2"
    local value=""

    case "$info_type" in
        ip)
            value=$(echo "$NETWORK_INTERFACES_IP" | grep -o "${interface}:[^;]*" | cut -d: -f2)
            ;;
        type)
            value=$(echo "$NETWORK_INTERFACES_TYPE" | grep -o "${interface}:[^;]*" | cut -d: -f2)
            ;;
        speed)
            value=$(echo "$NETWORK_INTERFACES_SPEED" | grep -o "${interface}:[^;]*" | cut -d: -f2)
            ;;
    esac

    echo "$value"
}

# Function to get all network interfaces based on OS
# Returns: Array of interface names
get_network_interfaces() {
    local interfaces=()

    case "$OS" in
        Linux)
            # Get all network interfaces except loopback and docker interfaces
            while IFS= read -r line; do
                if [[ $line =~ ^[0-9]+:\ ([^:]+): ]]; then
                    local iface="${BASH_REMATCH[1]}"
                    if [[ "$iface" != "lo" && ! "$iface" =~ ^docker ]]; then
                        interfaces+=("$iface")
                    fi
                fi
            done < <(ip link show)
            ;;
        MacOS)
            # Get all active network interfaces except loopback
            while IFS= read -r iface; do
                if [[ "$iface" != "lo0" ]]; then
                    interfaces+=("$iface")
                fi
            done < <(ifconfig -l | tr ' ' '\n' | grep -v '^$')
            ;;
        Windows)
            # Get network interfaces for Windows/MSYS2/Git Bash
            while IFS= read -r iface; do
                if [ -n "$iface" ]; then
                    interfaces+=("$iface")
                fi
            done < <(ipconfig | grep -E "^Ethernet|^Wireless" | awk -F: '{print $1}')
            ;;
        *)
            error_print "Unsupported operating system for network interface detection"
            return 1
            ;;
    esac

    debug_print "Found interfaces: ${interfaces[*]}"
    printf '%s\n' "${interfaces[@]}"
}

# Function to get IP address for a specific interface
# Args: $1 - Interface name
# Returns: IP address or empty string if not found
get_interface_ip() {
    local interface="$1"
    local ip=""

    case "$OS" in
        Linux)
            ip=$(ip addr show "$interface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
            ;;
        MacOS)
            ip=$(ifconfig "$interface" 2>/dev/null | grep "inet " | awk '{print $2}')
            ;;
        Windows)
            ip=$(ipconfig | grep -A 5 "$interface" | grep "IPv4" | awk '{print $NF}')
            ;;
    esac

    debug_print "Interface ${interface} has IP: ${ip}"
    echo "$ip"
}

# Function to determine connection type for an interface
# Args: $1 - Interface name
# Returns: Connection type (WiFi/Ethernet/unknown)
get_connection_type() {
    local interface="$1"
    local type="unknown"

    case "$OS" in
        Linux)
            if [[ "$interface" =~ ^wl ]]; then
                type="WiFi"
            elif [[ "$interface" =~ ^en || "$interface" =~ ^eth ]]; then
                type="Ethernet"
            fi
            ;;
        MacOS)
            if [[ "$interface" =~ ^en ]]; then
                if [[ "$interface" == "en0" ]]; then
                    type="WiFi"
                else
                    type="Ethernet"
                fi
            fi
            ;;
        Windows)
            if [[ "$interface" =~ "Wireless" ]]; then
                type="WiFi"
            elif [[ "$interface" =~ "Ethernet" ]]; then
                type="Ethernet"
            fi
            ;;
    esac

    debug_print "Interface ${interface} is type: ${type}"
    echo "$type"
}

# Function to get network speed for an interface
# Args: $1 - Interface name
# Returns: Speed in Mbps or "unknown"
get_interface_speed() {
    local interface="$1"
    local speed="unknown"

    case "$OS" in
        Linux)
            if [ -f "/sys/class/net/${interface}/speed" ]; then
                speed=$(cat "/sys/class/net/${interface}/speed")
            fi
            ;;
        MacOS)
            speed=$(networksetup -getmedia "$interface" 2>/dev/null | grep "Current" | awk '{print $3}')
            ;;
        Windows)
            speed=$(netsh wlan show interfaces | grep -A 2 "$interface" | grep "Transmit" | awk '{print $3}')
            ;;
    esac

    debug_print "Interface ${interface} speed: ${speed} Mbps"
    echo "$speed"
}

# Function to check if interface is active
# Args: $1 - Interface name
# Returns: 0 if active, 1 if not
is_interface_active() {
    local interface="$1"

    case "$OS" in
        Linux)
            if ip link show "$interface" 2>/dev/null | grep -q "UP"; then
                return 0
            fi
            ;;
        MacOS)
            if ifconfig "$interface" 2>/dev/null | grep -q "status: active"; then
                return 0
            fi
            ;;
        Windows)
            if ipconfig | grep -A 2 "$interface" | grep -q "Media State.*Connected"; then
                return 0
            fi
            ;;
    esac

    return 1
}

# Function to get all available network information
# Sets global variables: PRIMARY_IP, PRIMARY_INTERFACE, PRIMARY_TYPE
get_network_info() {
    local found_ips=false
    local interfaces=()

    # Read interfaces into array
    while IFS= read -r iface; do
        if [ -n "$iface" ]; then
            interfaces+=("$iface")
        fi
    done < <(get_network_interfaces)

    print_section_header "Network Interfaces"

    for interface in "${interfaces[@]}"; do
        if is_interface_active "$interface"; then
            local ip
            ip=$(get_interface_ip "$interface")
            local type
            type=$(get_connection_type "$interface")
            local speed
            speed=$(get_interface_speed "$interface")

            if [ -n "$ip" ]; then
                found_ips=true
                success_print "• ${type} (${interface}): ${ip} (${speed} Mbps)"

                # Store interface information
                store_interface_info "$interface" "$type" "$ip" "$speed"

                # Set primary interface if not already set
                if [ -z "$PRIMARY_IP" ]; then
                    PRIMARY_IP="$ip"
                    PRIMARY_INTERFACE="$interface"
                    PRIMARY_TYPE="$type"
                fi
            elif [ "$DEBUG" = true ]; then
                warning_print "• ${type} (${interface}): No IP address"
            fi
        fi
    done

    if ! $found_ips; then
        error_print "No active network interfaces found"
        return 1
    fi

    if [ "$DEBUG" = true ]; then
        print_section_header "Primary Network Connection"
        debug_print "Interface: ${PRIMARY_INTERFACE}"
        debug_print "Type: ${PRIMARY_TYPE}"
        debug_print "IP: ${PRIMARY_IP}"
    fi

    return 0
}

# Function to check port availability
# Args: $1 - port number
# Returns: 0 if port is available, 1 if not
check_port_availability() {
    local port="$1"

    if ! command -v nc >/dev/null 2>&1; then
        warning_print "netcat not available, skipping port check"
        return 0
    fi

    if nc -z localhost "$port" 2>/dev/null; then
        error_print "Port ${port} is already in use"
        return 1
    fi

    debug_print "Port ${port} is available"
    return 0
}

# Function to wait for port to become available
# Args: $1 - port number, $2 - timeout in seconds (default: 30)
wait_for_port() {
    local port="$1"
    local timeout="${2:-30}"
    local start_time
    start_time=$(date +%s)

    while true; do
        if nc -z localhost "$port" 2>/dev/null; then
            success_print "Port ${port} is now available"
            return 0
        fi

        if [ "$(($(date +%s) - start_time))" -ge "$timeout" ]; then
            error_print "Timeout waiting for port ${port}"
            return 1
        fi

        sleep 1
    done
}

# Execute check if script is sourced
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    error_print "This script should be sourced, not executed directly."
    exit 1
fi

# Export all functions and variables
export PRIMARY_IP PRIMARY_INTERFACE PRIMARY_TYPE
export NETWORK_INTERFACES_IP NETWORK_INTERFACES_TYPE NETWORK_INTERFACES_SPEED
export -f get_network_interfaces get_interface_ip get_connection_type
export -f get_interface_speed is_interface_active get_network_info
export -f check_port_availability wait_for_port
export -f store_interface_info get_interface_info
