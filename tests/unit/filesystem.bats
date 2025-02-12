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
    source "${BATS_TEST_DIRNAME}/../../libs/filesystem.sh"
    TEST_TEMP_DIR="$(mktemp -d)"
    BACKUP_DIR="${TEST_TEMP_DIR}/backups"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "check_disk_space should return available space" {
    case "$OS" in
        Linux|MacOS)
            echo "Filesystem     1K-blocks    Used Available Use% Mounted on" > "$TEST_TEMP_DIR/df_output"
            echo "/dev/sda1      61255492 28841088  29290020  50% /" >> "$TEST_TEMP_DIR/df_output"
            function df() { cat "$TEST_TEMP_DIR/df_output"; }
            export -f df
            ;;
        Windows)
            echo "Filesystem     1K-blocks    Used Available Use% Mounted on" > "$TEST_TEMP_DIR/df_output"
            echo "C:             61255492 28841088  29290020  50% /" >> "$TEST_TEMP_DIR/df_output"
            function df() { cat "$TEST_TEMP_DIR/df_output"; }
            export -f df
            ;;
    esac

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

@test "backup_directory should create backup archive" {
    local source_dir="${TEST_TEMP_DIR}/source"
    mkdir -p "$source_dir"
    echo "test data" > "${source_dir}/test.txt"

    run backup_directory "$source_dir" "test_backup"
    [ "$status" -eq 0 ]
    [ -f "${BACKUP_DIR}/test_backup_"* ]
}

@test "restore_from_backup should restore from backup" {
    # Create test backup
    local source_dir="${TEST_TEMP_DIR}/source"
    local restore_dir="${TEST_TEMP_DIR}/restore"
    mkdir -p "$source_dir"
    echo "test data" > "${source_dir}/test.txt"

    local backup_file="${BACKUP_DIR}/test_backup.tar.gz"
    tar -czf "$backup_file" -C "$(dirname "$source_dir")" "$(basename "$source_dir")"

    run restore_from_backup "$backup_file" "$restore_dir"
    [ "$status" -eq 0 ]
    [ -f "${restore_dir}/source/test.txt" ]
}

@test "clean_old_backups should remove old backups" {
    # Create test backups with different dates
    mkdir -p "$BACKUP_DIR"
    touch -d "31 days ago" "${BACKUP_DIR}/old_backup.tar.gz"
    touch -d "1 day ago" "${BACKUP_DIR}/new_backup.tar.gz"

    run clean_old_backups "$BACKUP_DIR" "30"
    [ "$status" -eq 0 ]
    [ ! -f "${BACKUP_DIR}/old_backup.tar.gz" ]
    [ -f "${BACKUP_DIR}/new_backup.tar.gz" ]
}

@test "cleanup_temp_files should remove temporary files" {
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

@test "create_temp_file should create unique temporary file" {
    run create_temp_file
    [ "$status" -eq 0 ]
    [ -f "$output" ]
    [[ "$output" =~ ${TEMP_PREFIX} ]]
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

@test "backup_directory should handle backup failures" {
    local source_dir="/nonexistent"
    run backup_directory "$source_dir" "test_backup"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Failed to create backup" ]]
}
