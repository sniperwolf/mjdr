#!/usr/bin/env bats

load 'test_helper'

@test "setup_test_env should create temporary directory" {
    setup_test_env
    [ -d "$TEST_TEMP_DIR" ]
    cleanup_test_env
}

@test "mock_docker should intercept docker commands" {
    setup_test_env
    mock_docker

    create_mock_docker_output "ps" "CONTAINER ID  NAME\n123  test_container"
    run docker ps
    [ "$status" -eq 0 ]
    [[ "$output" =~ "test_container" ]]

    cleanup_test_env
}

@test "mock_network should intercept network commands" {
    setup_test_env
    mock_network

    create_mock_network_output "ifconfig" "en0: inet 192.168.1.100"
    run ifconfig
    [ "$status" -eq 0 ]
    [[ "$output" =~ "192.168.1.100" ]]

    cleanup_test_env
}

@test "assert_permissions should verify file permissions" {
    setup_test_env
    local test_file="${TEST_TEMP_DIR}/test.txt"
    touch "$test_file"
    chmod 644 "$test_file"

    run assert_permissions "$test_file" "644"
    [ "$status" -eq 0 ]

    cleanup_test_env
}

@test "wait_for should timeout after specified duration" {
    run wait_for "false" 1
    [ "$status" -eq 1 ]
}
