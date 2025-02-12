#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    source "${BATS_TEST_DIRNAME}/../../libs/colors.sh"
    source "${BATS_TEST_DIRNAME}/../../libs/os_detect.sh"
    source "${BATS_TEST_DIRNAME}/../../libs/filesystem.sh"
    TEST_TEMP_DIR="$(mktemp -d)"
    OS="Linux"  # Set default OS for testing
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "check_disk_space should return available space" {
    echo "Filesystem     1K-blocks    Used Available Use% Mounted on" > "$TEST_TEMP_DIR/df_output"
    echo "/dev/sda1      61255492 28841088  29290020  50% /" >> "$TEST_TEMP_DIR/df_output"
    function df() { cat "$TEST_TEMP_DIR/df_output"; }
    export -f df

    run check_disk_space "$TEST_TEMP_DIR"
    [ "$status" -eq 0 ]
    [ "$output" -gt 0 ]
}

@test "verify_directory should create directory if not exists" {
    local test_dir="${TEST_TEMP_DIR}/new_dir"

    run verify_directory "$test_dir"
    [ "$status" -eq 0 ]
    [ -d "$test_dir" ]
}

@test "verify_directory should fail if not writable" {
    local test_dir="${TEST_TEMP_DIR}/readonly_dir"
    mkdir "$test_dir"
    chmod 555 "$test_dir"

    run verify_directory "$test_dir"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not writable" ]]

    chmod 755 "$test_dir"
}

@test "set_permissions should set correct permissions" {
    local test_file="${TEST_TEMP_DIR}/test_file"
    touch "$test_file"

    run set_permissions "$test_file" "644"
    [ "$status" -eq 0 ]

    local perms
    perms=$(stat -c %a "$test_file" 2>/dev/null || stat -f %Lp "$test_file")
    [ "$perms" = "644" ]
}

@test "create_directory_structure should create nested directories" {
    local base_dir="${TEST_TEMP_DIR}/base"
    local subdirs=("sub1" "sub2" "sub3")

    run create_directory_structure "$base_dir" "${subdirs[@]}"
    [ "$status" -eq 0 ]

    for dir in "${subdirs[@]}"; do
        [ -d "${base_dir}/${dir}" ]
    done
}

@test "cleanup_temp_files should remove old temporary files" {
    local temp_dir="${TEST_TEMP_DIR}/temp"
    mkdir -p "$temp_dir"

    # Create test temp files with different dates
    touch -d "2 days ago" "${temp_dir}/${TEMP_PREFIX}old.tmp"
    touch "${temp_dir}/${TEMP_PREFIX}new.tmp"

    TEMP="$temp_dir" run cleanup_temp_files
    [ "$status" -eq 0 ]
    [ ! -f "${temp_dir}/${TEMP_PREFIX}old.tmp" ]
    [ -f "${temp_dir}/${TEMP_PREFIX}new.tmp" ]
}

@test "check_filesystem should verify disk space and directories" {
    local test_dirs=("${TEST_TEMP_DIR}/dir1" "${TEST_TEMP_DIR}/dir2")

    # Mock check_disk_space to return sufficient space
    function check_disk_space() { echo "$((MIN_DISK_SPACE_MB + 1000))"; }
    export -f check_disk_space

    run check_filesystem "${test_dirs[@]}"
    [ "$status" -eq 0 ]

    for dir in "${test_dirs[@]}"; do
        [ -d "$dir" ]
    done
}

@test "check_filesystem should fail with insufficient space" {
    # Mock check_disk_space to return insufficient space
    function check_disk_space() { echo "$((MIN_DISK_SPACE_MB - 1000))"; }
    export -f check_disk_space

    run check_filesystem "${TEST_TEMP_DIR}/test"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Insufficient disk space" ]]
}

@test "verify_directory should handle permission errors" {
    if [ "$(id -u)" = "0" ]; then
        skip "This test cannot run as root"
    fi

    local test_dir="/root/test_dir"
    run verify_directory "$test_dir"
    [ "$status" -eq 1 ]
}
