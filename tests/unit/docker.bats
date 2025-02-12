#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../helpers/test_helper.bash"

# Setup runs before each test
setup() {
    # Load the docker module
    source "${BATS_TEST_DIRNAME}/../../libs/docker.sh"
    # Create temporary test directory
    TEST_TEMP_DIR="$(mktemp -d)"
}

# Teardown runs after each test
teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# Test container status detection
@test "get_container_status should return 'not_found' for non-existent container" {
    run get_container_status "non_existent_container"
    [ "$status" -eq 0 ]
    [ "$output" = "not_found" ]
}

@test "get_container_status should return 'running' for running container" {
    # Create mock Docker ps output
    echo "test_container" > "$TEST_TEMP_DIR/ps_output"
    function docker() {
        if [[ "$*" == "ps --format '{{.Names}}'" ]]; then
            cat "$TEST_TEMP_DIR/ps_output"
            return 0
        fi
    }
    export -f docker

    run get_container_status "test_container"
    [ "$status" -eq 0 ]
    [ "$output" = "running" ]
}

# Test version verification
@test "verify_version should correctly compare versions" {
    run verify_version "20.10.0" "20.10.0"
    [ "$status" -eq 0 ]

    run verify_version "20.10.1" "20.10.0"
    [ "$status" -eq 0 ]

    run verify_version "20.9.0" "20.10.0"
    [ "$status" -eq 1 ]
}

# Test Docker installation check
@test "check_docker_installation should fail if Docker is not installed" {
    function command() { return 1; }
    export -f command

    run check_docker_installation
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Docker is not installed" ]]
}
