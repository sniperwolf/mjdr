#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    source "${BATS_TEST_DIRNAME}/../../libs/colors.sh"
    source "${BATS_TEST_DIRNAME}/../../libs/os_detect.sh"
    source "${BATS_TEST_DIRNAME}/../../libs/network.sh"
    TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "store_interface_info should store interface information" {
    run store_interface_info "eth0" "Ethernet" "192.168.1.100" "1000"
    [ "$status" -eq 0 ]
    [[ "$NETWORK_INTERFACES_IP" =~ "eth0:192.168.1.100" ]]
    [[ "$NETWORK_INTERFACES_TYPE" =~ "eth0:Ethernet" ]]
    [[ "$NETWORK_INTERFACES_SPEED" =~ "eth0:1000" ]]
}

@test "get_interface_info should retrieve stored information" {
    store_interface_info "eth0" "Ethernet" "192.168.1.100" "1000"

    run get_interface_info "eth0" "ip"
    [ "$output" = "192.168.1.100" ]

    run get_interface_info "eth0" "type"
    [ "$output" = "Ethernet" ]

    run get_interface_info "eth0" "speed"
    [ "$output" = "1000" ]
}

@test "get_network_interfaces should detect interfaces based on OS" {
    case "$OS" in
        Linux)
            echo "1: lo: <LOOPBACK,UP,LOWER_UP>" > "$TEST_TEMP_DIR/ip_link"
            echo "2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP>" >> "$TEST_TEMP_DIR/ip_link"
            echo "3: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP>" >> "$TEST_TEMP_DIR/ip_link"
            function ip() { cat "$TEST_TEMP_DIR/ip_link"; }
            export -f ip
            ;;
        MacOS)
            echo "lo0 en0 en1" > "$TEST_TEMP_DIR/ifconfig_list"
            function ifconfig() {
                if [[ "$1" = "-l" ]]; then
                    cat "$TEST_TEMP_DIR/ifconfig_list"
                fi
            }
            export -f ifconfig
            ;;
        Windows)
            echo "Ethernet adapter Ethernet:" > "$TEST_TEMP_DIR/ipconfig"
            echo "Wireless adapter Wi-Fi:" >> "$TEST_TEMP_DIR/ipconfig"
            function ipconfig() { cat "$TEST_TEMP_DIR/ipconfig"; }
            export -f ipconfig
            ;;
    esac

    run get_network_interfaces
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "get_interface_ip should return IP address" {
    case "$OS" in
        Linux)
            echo "inet 192.168.1.100/24" > "$TEST_TEMP_DIR/ip_addr"
            function ip() { cat "$TEST_TEMP_DIR/ip_addr"; }
            export -f ip
            ;;
        MacOS)
            echo "inet 192.168.1.100 netmask 0xffffff00" > "$TEST_TEMP_DIR/ifconfig"
            function ifconfig() { cat "$TEST_TEMP_DIR/ifconfig"; }
            export -f ifconfig
            ;;
        Windows)
            echo "IPv4 Address. . . . . . . . . . . : 192.168.1.100" > "$TEST_TEMP_DIR/ipconfig"
            function ipconfig() { cat "$TEST_TEMP_DIR/ipconfig"; }
            export -f ipconfig
            ;;
    esac

    run get_interface_ip "test_interface"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "192.168.1.100" ]]
}

@test "get_connection_type should identify interface types" {
    case "$OS" in
        Linux)
            run get_connection_type "wlan0"
            [ "$output" = "WiFi" ]
            run get_connection_type "eth0"
            [ "$output" = "Ethernet" ]
            ;;
        MacOS)
            run get_connection_type "en0"
            [ "$output" = "WiFi" ]
            run get_connection_type "en1"
            [ "$output" = "Ethernet" ]
            ;;
        Windows)
            run get_connection_type "Wireless"
            [ "$output" = "WiFi" ]
            run get_connection_type "Ethernet"
            [ "$output" = "Ethernet" ]
            ;;
    esac
}

@test "get_interface_speed should return interface speed" {
    case "$OS" in
        Linux)
            echo "1000" > "$TEST_TEMP_DIR/speed"
            function cat() {
                if [[ "$1" =~ /speed$ ]]; then
                    cat "$TEST_TEMP_DIR/speed"
                fi
            }
            export -f cat
            ;;
        MacOS)
            echo "Current Speed: 1000" > "$TEST_TEMP_DIR/networksetup"
            function networksetup() { cat "$TEST_TEMP_DIR/networksetup"; }
            export -f networksetup
            ;;
        Windows)
            echo "    Transmit Rate:           1000" > "$TEST_TEMP_DIR/netsh"
            function netsh() { cat "$TEST_TEMP_DIR/netsh"; }
            export -f netsh
            ;;
    esac

    run get_interface_speed "test_interface"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "1000" ]]
}

@test "is_interface_active should detect active interfaces" {
    case "$OS" in
        Linux)
            echo "up" > "$TEST_TEMP_DIR/operstate"
            function grep() {
                if [[ "$2" =~ /operstate$ ]]; then
                    cat "$TEST_TEMP_DIR/operstate"
                fi
            }
            export -f grep
            ;;
        MacOS)
            echo "status: active" > "$TEST_TEMP_DIR/ifconfig"
            function ifconfig() { cat "$TEST_TEMP_DIR/ifconfig"; }
            export -f ifconfig
            ;;
        Windows)
            echo "Media State . . . . . . . . . . . : Connected" > "$TEST_TEMP_DIR/ipconfig"
            function ipconfig() { cat "$TEST_TEMP_DIR/ipconfig"; }
            export -f ipconfig
            ;;
    esac

    run is_interface_active "test_interface"
    [ "$status" -eq 0 ]
}

@test "get_network_info should collect all network information" {
    # Mock successful interface detection
    function get_network_interfaces() { echo "test_interface"; }
    function is_interface_active() { return 0; }
    function get_interface_ip() { echo "192.168.1.100"; }
    function get_connection_type() { echo "Ethernet"; }
    function get_interface_speed() { echo "1000"; }
    export -f get_network_interfaces is_interface_active get_interface_ip get_connection_type get_interface_speed

    run get_network_info
    [ "$status" -eq 0 ]
    [ -n "$PRIMARY_IP" ]
    [ -n "$PRIMARY_INTERFACE" ]
    [ -n "$PRIMARY_TYPE" ]
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
