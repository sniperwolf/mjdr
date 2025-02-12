#!/usr/bin/env bats

# Determine helper path
if [[ -z "${BATS_HELPER_PATH:-}" ]]; then
    # When running locally
    BATS_HELPER_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")/../helpers" && pwd)"
fi

load "${BATS_HELPER_PATH}/test_helper.bash"

setup() {
    source "${BATS_TEST_DIRNAME}/../../libs/colors.sh"
    source "${BATS_TEST_DIRNAME}/../../libs/os_detect.sh"
    source "${BATS_TEST_DIRNAME}/../../libs/ui.sh"
    TEST_TEMP_DIR="$(mktemp -d)"
    export TERM=xterm-256color
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "clear_screen should use appropriate command based on OS" {
    case "$OS" in
        Windows)
            function cmd.exe() { echo "cls called"; }
            export -f cmd.exe
            run clear_screen
            [[ "$output" =~ "cls called" ]]
            ;;
        *)
            function clear() { echo "clear called"; }
            export -f clear
            run clear_screen
            [[ "$output" =~ "clear called" ]]
            ;;
    esac
}

@test "display_banner should show default banner if file not exists" {
    run display_banner
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Jellyfin Manager" ]]
}

@test "display_banner should show custom banner if file exists" {
    echo "Custom Banner" > "$TEST_TEMP_DIR/banner.txt"
    BANNER_FILE="$TEST_TEMP_DIR/banner.txt" run display_banner
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Custom Banner" ]]
}

@test "show_spinner should display spinning animation" {
    # Create a long-running process
    sleep 1 &
    local pid=$!

    run show_spinner "$pid"
    [ "$status" -eq 0 ]
}

@test "show_progress should display progress bar" {
    run show_progress 50 100
    [ "$status" -eq 0 ]
    [[ "$output" =~ "50%" ]]
}

@test "get_confirmation should handle yes input" {
    echo "y" > "$TEST_TEMP_DIR/input"
    run get_confirmation "Continue?" < "$TEST_TEMP_DIR/input"
    [ "$status" -eq 0 ]
}

@test "get_confirmation should handle no input" {
    echo "n" > "$TEST_TEMP_DIR/input"
    run get_confirmation "Continue?" < "$TEST_TEMP_DIR/input"
    [ "$status" -eq 1 ]
}

@test "get_confirmation should repeat on invalid input" {
    echo -e "invalid\ny" > "$TEST_TEMP_DIR/input"
    run get_confirmation "Continue?" < "$TEST_TEMP_DIR/input"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Please answer yes" ]]
}

@test "show_menu should display options and handle selection" {
    local options=("Option 1" "Option 2" "Option 3")
    echo "1" > "$TEST_TEMP_DIR/input"
    run show_menu "Test Menu" "${options[@]}" < "$TEST_TEMP_DIR/input"
    [ "$status" -eq 0 ]
}

@test "show_menu should handle quit option" {
    local options=("Option 1" "Option 2")
    echo "q" > "$TEST_TEMP_DIR/input"
    run show_menu "Test Menu" "${options[@]}" < "$TEST_TEMP_DIR/input"
    [ "$status" -eq 255 ]
}

@test "get_user_input should validate input" {
    echo "test123" > "$TEST_TEMP_DIR/input"
    run get_user_input "Enter value" "^test[0-9]+$" < "$TEST_TEMP_DIR/input"
    [ "$status" -eq 0 ]
    [ "$output" = "test123" ]
}

@test "get_user_input should repeat on invalid input" {
    echo -e "invalid\ntest123" > "$TEST_TEMP_DIR/input"
    run get_user_input "Enter value" "^test[0-9]+$" < "$TEST_TEMP_DIR/input"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Invalid input" ]]
    [[ "$output" =~ "test123" ]]
}

@test "show_error should display error message" {
    run show_error "Test error"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Test error" ]]
}

@test "show_error should handle retry option" {
    echo "y" > "$TEST_TEMP_DIR/input"
    run show_error "Test error" true < "$TEST_TEMP_DIR/input"
    [ "$status" -eq 0 ]
}

@test "display_qr_code should handle missing qrencode" {
    function command() { return 1; }
    export -f command

    run display_qr_code "test content"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not installed" ]]
}

@test "display_qr_code should generate QR code" {
    function qrencode() { echo "QR Code generated"; }
    export -f qrencode

    run display_qr_code "test content"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "QR Code generated" ]]
}

@test "show_service_status should display running status" {
    run show_service_status "test-service" "running"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "test-service" ]]
    [[ "$output" =~ "running" ]]
}

@test "show_service_status should display stopped status" {
    run show_service_status "test-service" "stopped"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "test-service" ]]
    [[ "$output" =~ "stopped" ]]
}

@test "show_service_status should display error status" {
    run show_service_status "test-service" "error"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "test-service" ]]
    [[ "$output" =~ "error" ]]
}

@test "show_system_info should display system information" {
    OS="TestOS"
    OS_VERSION="1.0"
    OS_ARCH="x86_64"
    PRIMARY_IP="192.168.1.100"
    PRIMARY_INTERFACE="eth0"
    PRIMARY_TYPE="Ethernet"

    function get_system_memory() { echo "1024"; }
    export -f get_system_memory

    run show_system_info
    [ "$status" -eq 0 ]
    [[ "$output" =~ "TestOS" ]]
    [[ "$output" =~ "1.0" ]]
    [[ "$output" =~ "x86_64" ]]
    [[ "$output" =~ "192.168.1.100" ]]
    [[ "$output" =~ "eth0" ]]
    [[ "$output" =~ "1024" ]]
}
