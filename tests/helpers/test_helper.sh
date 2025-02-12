#!/usr/bin/env bash

# Set testing environment
export TESTING=true
export BATS_TEST_DIRNAME
export BATS_TEST_FILENAME

# Load bats-support and bats-assert if available
load_lib() {
    local name="$1"
    local lib="/usr/local/lib/bats/${name}/load.bash"
    if [ -f "$lib" ]; then
        load "$lib"
    fi
}

load_lib "bats-support"
load_lib "bats-assert"

# Helper function to create temporary test environment
setup_test_env() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

# Helper function to cleanup test environment
cleanup_test_env() {
    if [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Mock Docker commands
mock_docker() {
    export DOCKER_MOCK_DIR="$TEST_TEMP_DIR/docker_mock"
    mkdir -p "$DOCKER_MOCK_DIR"

    function docker() {
        case "$1" in
            "ps")
                cat "$DOCKER_MOCK_DIR/ps_output" 2>/dev/null || true
                ;;
            "inspect")
                cat "$DOCKER_MOCK_DIR/inspect_output" 2>/dev/null || true
                ;;
            "logs")
                cat "$DOCKER_MOCK_DIR/logs_output" 2>/dev/null || true
                ;;
            *)
                echo "MOCK_DOCKER_CALL: $*" >&3
                ;;
        esac
        return 0
    }
    export -f docker
}

# Mock network commands
mock_network() {
    export NETWORK_MOCK_DIR="$TEST_TEMP_DIR/network_mock"
    mkdir -p "$NETWORK_MOCK_DIR"

    function ip() {
        cat "$NETWORK_MOCK_DIR/ip_output" 2>/dev/null || true
    }

    function ifconfig() {
        cat "$NETWORK_MOCK_DIR/ifconfig_output" 2>/dev/null || true
    }

    function nc() {
        return 0
    }

    export -f ip ifconfig nc
}

# Helper function to create mock Docker output
create_mock_docker_output() {
    local type="$1"
    local content="$2"
    echo "$content" > "$DOCKER_MOCK_DIR/${type}_output"
}

# Helper function to create mock network output
create_mock_network_output() {
    local type="$1"
    local content="$2"
    echo "$content" > "$NETWORK_MOCK_DIR/${type}_output"
}

# Helper function to assert file permissions
assert_permissions() {
    local file="$1"
    local expected_perms="$2"
    local actual_perms

    if [ "$OS" = "MacOS" ]; then
        actual_perms=$(stat -f "%Lp" "$file")
    else
        actual_perms=$(stat -c "%a" "$file")
    fi

    [ "$actual_perms" = "$expected_perms" ]
}

# Helper function to assert directory exists and is writable
assert_directory() {
    local dir="$1"
    [ -d "$dir" ]
    [ -w "$dir" ]
}

# Helper function to create test files
create_test_file() {
    local path="$1"
    local content="${2:-test content}"
    mkdir -p "$(dirname "$path")"
    echo "$content" > "$path"
}

# Helper function to simulate system load
simulate_load() {
    local cpu="${1:-50}"
    local mem="${2:-512}"

    # Create mock system info
    create_mock_system_info "$cpu" "$mem"
}

# Helper function to create mock system info
create_mock_system_info() {
    local cpu="$1"
    local mem="$2"

    case "$OS" in
        Linux)
            echo "MemTotal:        $((mem * 1024)) kB" > "$TEST_TEMP_DIR/meminfo"
            echo "cpu  $cpu" > "$TEST_TEMP_DIR/stat"
            ;;
        MacOS)
            echo "hw.memsize: $((mem * 1024 * 1024))" > "$TEST_TEMP_DIR/sysctl"
            ;;
        Windows)
            echo "TotalPhysicalMemory=$((mem * 1024 * 1024))" > "$TEST_TEMP_DIR/wmic"
            ;;
    esac
}

# Helper function to assert log contains message
assert_log_contains() {
    local log_file="$1"
    local message="$2"
    grep -q "$message" "$log_file"
}

# Helper function to wait for condition
wait_for() {
    local cmd="$1"
    local timeout="${2:-10}"
    local interval="${3:-1}"

    local end_time=$(($(date +%s) + timeout))

    while [ "$(date +%s)" -lt "$end_time" ]; do
        if eval "$cmd"; then
            return 0
        fi
        sleep "$interval"
    done

    return 1
}

# Export all helper functions
export -f setup_test_env cleanup_test_env
export -f mock_docker mock_network
export -f create_mock_docker_output create_mock_network_output
export -f assert_permissions assert_directory
export -f create_test_file simulate_load
export -f create_mock_system_info assert_log_contains
export -f wait_for
