#!/usr/bin/env bats

load "${BATS_HELPER_PATH}/test_helper.bash"

setup() {
    source "${BATS_TEST_DIRNAME}/../../libs/colors.sh"
    source "${BATS_TEST_DIRNAME}/../../libs/os_detect.sh"
    TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "detect_os should identify Linux" {
    function uname() { echo "Linux"; }
    export -f uname

    run detect_os
    [ "$status" -eq 0 ]
    [ "$OS" = "Linux" ]
}

@test "detect_os should identify MacOS" {
    function uname() { echo "Darwin"; }
    export -f uname

    run detect_os
    [ "$status" -eq 0 ]
    [ "$OS" = "MacOS" ]
}

@test "detect_os should identify Windows" {
    function uname() { echo "MINGW64_NT-10.0"; }
    export -f uname

    run detect_os
    [ "$status" -eq 0 ]
    [ "$OS" = "Windows" ]
}

@test "get_system_memory should return valid memory size" {
    # Mock different OS environments
    case "$OS" in
        Linux)
            echo "              total        used        free" > "$TEST_TEMP_DIR/free_output"
            echo "Mem:          16384        8192        8192" >> "$TEST_TEMP_DIR/free_output"
            function free() { cat "$TEST_TEMP_DIR/free_output"; }
            export -f free
            ;;
        MacOS)
            function sysctl() { echo "hw.memsize: 17179869184"; }
            export -f sysctl
            ;;
        Windows)
            echo "TotalPhysicalMemory=17179869184" > "$TEST_TEMP_DIR/wmic_output"
            function wmic() { cat "$TEST_TEMP_DIR/wmic_output"; }
            export -f wmic
            ;;
    esac

    run get_system_memory
    [ "$status" -eq 0 ]
    [ "$output" -gt 0 ]
}

@test "check_system_requirements should verify memory requirements" {
    function get_system_memory() { echo "512"; }
    export -f get_system_memory

    run check_system_requirements
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Insufficient memory" ]]
}

@test "check_system_requirements should verify required commands" {
    function command() { return 1; }
    export -f command

    run check_system_requirements
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Required command not found" ]]
}

@test "adapt_paths should convert Windows paths" {
    OS="Windows"
    USB_MOUNT_PATH="C:\\Data"
    MEDIA_PATH="D:\\Media"
    CONFIG_PATH="E:\\Config"

    run adapt_paths
    [ "$status" -eq 0 ]
    [[ "$USB_MOUNT_PATH" =~ ^/[c-eC-E]/ ]]
}

@test "get_temp_dir should return correct path" {
    case "$OS" in
        Windows)
            TEMP="C:\\Temp"
            run get_temp_dir
            [ "$output" = "$TEMP" ]
            ;;
        *)
            run get_temp_dir
            [ "$output" = "/tmp" ]
            ;;
    esac
}
