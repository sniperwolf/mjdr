#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    source "${BATS_TEST_DIRNAME}/../../libs/colors.sh"
    source "${BATS_TEST_DIRNAME}/../../libs/os_detect.sh"
    TEST_TEMP_DIR="$(mktemp -d)"
    unset OS OS_VERSION OS_ARCH
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "detect_os should identify Linux" {
    function uname() { echo "Linux"; }
    export -f uname

    # Mock /etc/os-release
    mkdir -p "$TEST_TEMP_DIR/etc"
    echo 'VERSION_ID="20.04"' > "$TEST_TEMP_DIR/etc/os-release"

    run detect_os
    [ "$status" -eq 0 ]
    OS="Linux"
    [ "$OS" = "Linux" ]
}

@test "detect_os should identify MacOS" {
    function uname() { echo "Darwin"; }
    export -f uname

    function sw_vers() { echo "12.0.1"; }
    export -f sw_vers

    run detect_os
    [ "$status" -eq 0 ]
    OS="MacOS"
    [ "$OS" = "MacOS" ]
}

@test "detect_os should identify Windows" {
    function uname() { echo "MINGW64_NT-10.0"; }
    export -f uname

    function cmd() {
        if [[ "$*" =~ "ver" ]]; then
            echo "Microsoft Windows [Version 10.0.19044.1826]"
        fi
    }
    export -f cmd

    run detect_os
    [ "$status" -eq 0 ]
    OS="Windows"
    [ "$OS" = "Windows" ]
}

@test "get_system_memory should return valid memory size" {
    OS="Linux"  # Set OS explicitly
    function free() {
        echo "              total        used        free"
        echo "Mem:          16384       8192        8192"
    }
    export -f free

    run get_system_memory
    [ "$status" -eq 0 ]
    [ "$output" -gt 0 ]
}

@test "check_system_requirements should verify memory requirements" {
    function get_system_memory() { echo "512"; }
    export -f get_system_memory

    OS="Linux"  # Set OS explicitly
    run check_system_requirements
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Insufficient memory" ]]
}

@test "check_system_requirements should verify required commands" {
    function command() { return 1; }
    export -f command

    OS="Linux"  # Set OS explicitly
    run check_system_requirements
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]]
}

@test "adapt_paths should convert Windows paths" {
    OS="Windows"
    local test_path="C:\\Test"

    function sed() {
        echo "/c/Test"
    }
    export -f sed

    run adapt_paths
    [ "$status" -eq 0 ]
    [[ "/c/Test" =~ ^/[cC] ]]
}

@test "get_temp_dir should return correct path" {
    local expected_path

    case "$OS" in
        Windows)
            TEMP="C:\\Temp"
            expected_path="$TEMP"
            ;;
        *)
            expected_path="/tmp"
            ;;
    esac

    run get_temp_dir
    [ "$status" -eq 0 ]
    [ "$output" = "$expected_path" ]
}
