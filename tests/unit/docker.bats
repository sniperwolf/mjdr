#!/usr/bin/env bats

load '../helpers/test_helper'

# Load test helper
load "${BATS_HELPER_PATH}/test_helper.bash"

setup() {
    source "${BATS_TEST_DIRNAME}/../../libs/colors.sh"
    source "${BATS_TEST_DIRNAME}/../../libs/os_detect.sh"
    source "${BATS_TEST_DIRNAME}/../../libs/docker.sh"
    TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "get_container_status should return 'not_found' for non-existent container" {
    function docker() {
        return 1
    }
    export -f docker

    run get_container_status "non_existent_container"
    [ "$status" -eq 0 ]
    [ "$output" = "not_found" ]
}

@test "get_container_status should return 'running' for running container" {
    CONTAINER_STATUS=""  # Reset the status
    function docker() {
        case "$1" in
            "ps")
                if [[ "$*" =~ "-q -f name=^/test_container$" ]]; then
                    echo "123456789"  # Mock container ID
                    return 0
                fi
                ;;
        esac
        return 1
    }
    export -f docker

    run get_container_status "test_container"
    echo "Output: $output"  # Debug output
    echo "Status: $status"  # Debug output
    [ "$status" -eq 0 ]
    [ "$output" = "running" ]
}

@test "verify_version should correctly compare versions" {
    run verify_version "20.10.0" "20.10.0"
    [ "$status" -eq 0 ]

    run verify_version "20.10.1" "20.10.0"
    [ "$status" -eq 0 ]

    run verify_version "20.9.0" "20.10.0"
    [ "$status" -eq 1 ]
}

@test "check_docker_installation should fail if Docker is not installed" {
    function command() { return 1; }
    export -f command

    run check_docker_installation
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Docker is not installed" ]]
}

@test "check_docker_compose should fail if compose is not available" {
    function docker() {
        if [[ "$*" =~ "compose version" ]]; then
            return 1
        fi
    }
    export -f docker

    run check_docker_compose
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Docker Compose V2 plugin is not available" ]]
}

@test "validate_compose_file should fail if file not found" {
    run validate_compose_file "non_existent_file.yaml"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]]
}

@test "start_container should handle docker compose errors" {
    function docker() {
        if [[ "$*" =~ "compose" ]]; then
            return 1
        fi
    }
    export -f docker

    run start_container "test.yaml"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Failed to start container" ]]
}

@test "stop_container should handle docker compose errors" {
    function docker() {
        if [[ "$*" =~ "compose" ]]; then
            return 1
        fi
    }
    export -f docker

    run stop_container "test.yaml"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Failed to stop container" ]]
}

@test "get_container_logs should return logs" {
    function docker() {
        if [[ "$*" =~ "logs" ]]; then
            echo "test log message"
        fi
    }
    export -f docker

    run get_container_logs "test_container"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "test log message" ]]
}

@test "check_container_health should handle different states" {
    local container_name="test_container"

    # Test healthy state
    function docker() {
        echo "healthy"
    }
    export -f docker
    run check_container_health "$container_name"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "healthy" ]]

    # Test unhealthy state
    function docker() {
        echo "unhealthy"
    }
    export -f docker
    run check_container_health "$container_name"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "unhealthy" ]]
}

@test "wait_for_container should handle timeout" {
    function docker() {
        return 0
    }
    export -f docker

    run wait_for_container "test_container" 1
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Timeout" ]]
}

@test "cleanup_docker should execute cleanup commands" {
    local -a executed_commands=()

    function docker() {
        case "$*" in
            *"container prune -f"*)
                executed_commands+=("container_prune")
                ;;
            *"network prune -f"*)
                executed_commands+=("network_prune")
                ;;
        esac
        return 0
    }
    export -f docker

    DEBUG=true  # Enable debug mode for more output
    run cleanup_docker
    echo "Executed commands: ${executed_commands[*]}"  # Debug output
    [ "$status" -eq 0 ]
    [[ " ${executed_commands[*]} " == *" container_prune "* ]]
}
