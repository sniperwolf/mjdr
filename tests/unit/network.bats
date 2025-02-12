#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    source "${BATS_TEST_DIRNAME}/../../libs/colors.sh"
    source "${BATS_TEST_DIRNAME}/../../libs/os_detect.sh"
    source "${BATS_TEST_DIRNAME}/../../libs/network.sh"
    TEST_TEMP_DIR="$(mktemp -d)"
    OS="Linux"  # Set default OS for testing
    NETWORK_INTERFACES_IP=""
    NETWORK_INTERFACES_TYPE=""
    NETWORK_INTERFACES_SPEED=""
    PRIMARY_IP=""
    PRIMARY_INTERFACE=""
    PRIMARY_TYPE=""
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "store_interface_info should store interface information" {
    store_interface_info "eth0" "Ethernet" "192.168.1.100" "1000"
    [[ "$NETWORK_INTERFACES_IP" == *"eth0:192.168.1.100"* ]]
    [[ "$NETWORK_INTERFACES_TYPE" == *"eth0:Ethernet"* ]]
    [[ "$NETWORK_INTERFACES_SPEED" == *"eth0:1000"* ]]
}

@test "get_interface_info should retrieve stored information" {
    store_interface_info "eth0" "Ethernet" "192.168.1.100" "1000"

    local ip
    ip=$(get_interface_info "eth0" "ip")
    [ "$ip" = "192.168.1.100" ]

    local type
    type=$(get_interface_info "eth0" "type")
    [ "$type" = "Ethernet" ]

    local speed
    speed=$(get_interface_info "eth0" "speed")
    [ "$speed" = "1000" ]
}

@test "get_network_interfaces should detect interfaces based on OS" {
    echo "2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP>" > "$TEST_TEMP_DIR/interfaces"
    function ip() {
        if [[ "$*" =~ "link show" ]]; then
            cat "$TEST_TEMP_DIR/interfaces"
        fi
    }
    export -f ip

    run get_network_interfaces
    [ "$status" -eq 0 ]
    [[ "$output" == *"eth0"* ]]
}

@test "get_interface_ip should return IP address" {
    echo "inet 192.168.1.100/24" > "$TEST_TEMP_DIR/addr"
    function ip() {
        if [[ "$*" =~ "addr show" ]]; then
            cat "$TEST_TEMP_DIR/addr"
        fi
    }
    export -f ip

    run get_interface_ip "eth0"
    [ "$status" -eq 0 ]
    [[ "$output" == "192.168.1.100" ]]
}

@test "get_connection_type should identify interface types" {
    run get_connection_type "wlan0"
    [ "$output" = "WiFi" ]

    run get_connection_type "eth0"
    [ "$output" = "Ethernet" ]
}

@test "get_interface_speed should return interface speed" {
    mkdir -p "$TEST_TEMP_DIR/sys/class/net/eth0"
    echo "1000" > "$TEST_TEMP_DIR/sys/class/net/eth0/speed"
    function cat() {
        if [[ "$1" =~ "/speed" ]]; then
            echo "1000"
        fi
    }
    export -f cat

    run get_interface_speed "eth0"
    [ "$status" -eq 0 ]
    [[ "$output" == "1000" ]]
}

@test "is_interface_active should detect active interfaces" {
    function ip() {
        if [[ "$*" =~ "link show" ]]; then
            echo "UP"
        fi
    }
    export -f ip

    run is_interface_active "eth0"
    [ "$status" -eq 0 ]
}

@test "get_network_info should collect all network information" {
    function get_network_interfaces() { echo "eth0"; }
    function is_interface_active() { return 0; }
    function get_interface_ip() { echo "192.168.1.100"; }
    function get_connection_type() { echo "Ethernet"; }
    function get_interface_speed() { echo "1000"; }
    export -f get_network_interfaces is_interface_active get_interface_ip get_connection_type get_interface_speed

    run get_network_info
    [ "$status" -eq 0 ]
    [[ "$output" == *"192.168.1.100"* ]]
    [[ "$output" == *"Ethernet"* ]]
    [[ "$output" == *"1000"* ]]
}

@test "check_port_availability should detect used ports" {
    function nc() { return 0; }
    export -f nc

    run check_port_availability "8096"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "already in use" ]]
}

@test "wait_for_port should timeout after specified duration" {
    function nc() { return 1; }
    export -f nc

    run wait_for_port "8096" "2"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Timeout" ]]
}
